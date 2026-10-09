# Project vcpkg overlays

This directory holds version-controlled project configuration. Install the vcpkg
package manager separately (for example `~/vcpkg` or `external/vcpkg`) and use
`VCPKG_ROOT` or the boilerplate's automatic discovery.

- `ports/`: project-owned overlay ports. `library1` and `library2` build from this
  checkout using relative paths and share the existing library install rules.
- `triplets/`: custom shared-library settings for Linux, Windows and macOS,
  without overriding built-in triplets.
- `../vcpkg-configuration.json`: registers both overlays for manifest installs.
- `../vcpkg.json`: dependencies/features and the pinned builtin registry baseline.
- `../CMakePresets.json`: chooses the provider, build settings and target triplet.

From the repository root:

```sh
cmake --preset vcpkg-release
cmake --preset vcpkg-linux-shared
cmake --build --preset vcpkg-linux-shared
```

The root project builds the example libraries via `add_subdirectory`, so its
manifest deliberately does not depend on its own ports. To install those ports
independently:

```sh
vcpkg install library1 library2 --classic --overlay-ports=vcpkg/ports
```

An external manifest consumer must register this checkout's `vcpkg/ports` in its
own configuration and add the desired libraries to its dependencies. Local ports
reference mutable checkout sources: after edits, remove/reinstall the packages
with `--binarysource=clear` to avoid stale cached binaries.

For portable release ports, use `boilerplate_vcpkg_port()` with URL/SHA512 as
explained in [the library documentation](../lib/README.md#publishing-libraries-through-vcpkg).
Generated ports remain in the build directory for review before copying them
into `ports/`; ordinary configuration does not rewrite tracked port files.

See the [vcpkg configuration reference](https://learn.microsoft.com/en-us/vcpkg/reference/vcpkg-configuration-json).

## Release registry

This repository is also a Git registry, following the official
[registry layout](https://learn.microsoft.com/en-us/vcpkg/maintainers/registries).
The directories at the **repository root** are the publishable packages:

```text
ports/library{1,2}/          portfile.cmake, vcpkg.json, usage
versions/baseline.json      default package versions
versions/l-/library{1,2}.json  version -> port directory git-tree
vcpkg/release.json          source version, tag, commit, SHA512, vcpkg revision
tests/registry-consumer/    independent CMake application
```

The `1.0.0` ports download source commit
`60b591ca25b2c58d2ece386b7e649b34138bf5fd` and verify its archive SHA512.
They do not read the registry checkout's `lib/` directory. The source tag is
`v1.0.0`; it is created by the publish workflow, and the ports use the immutable
commit rather than depending on a movable tag. The **registry baseline** is a
different commit: it must contain `ports/` and `versions/`. The source commit
alone is not a usable registry baseline.

### Independent consumer

After committing and pushing the registry files, obtain the full registry commit
with `git rev-parse HEAD`, or copy the baseline from the GitHub Release notes.
In a completely separate project, use this `vcpkg-configuration.json`, replacing
`<REGISTRY_COMMIT>` with that 40-character SHA:

```json
{
  "default-registry": {
    "kind": "builtin",
    "baseline": "3b6ec96bfa4d7dacd8ab1a97676a82c9cb18111e"
  },
  "registries": [{
    "kind": "git",
    "repository": "https://github.com/cpp20120/cmake_boilerplate.git",
    "baseline": "<REGISTRY_COMMIT>",
    "packages": ["library1", "library2"]
  }]
}
```

Add dependencies to the consumer's `vcpkg.json`:

```json
{
  "name": "my-consumer",
  "version": "1.0.0",
  "dependencies": [
    { "name": "library1", "version>=": "1.0.0" },
    { "name": "library2", "version>=": "1.0.0" }
  ]
}
```

The CMake interface is ordinary package consumption:

```cmake
find_package(library1 1 CONFIG REQUIRED)
find_package(library2 1 CONFIG REQUIRED)
add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE library1::library1 library2::library2)
```

`#include <library1.hpp>` / `#include <library2.hpp>` expose the APIs. The imported
targets carry include paths, static export definitions and the `Threads`
dependency. The triplet chooses static or shared linkage.

To produce a ready-to-build sample with a concrete baseline (run from this
repository, with CMake 3.26+ and Git available):

```sh
cmake -DACTION=prepare -DOUTPUT=/tmp/my-consumer \
  -DREPOSITORY=https://github.com/cpp20120/cmake_boilerplate.git \
  -DBASELINE="$(git rev-parse HEAD)" -P scripts/Registry.cmake
cd /tmp/my-consumer
"$VCPKG_ROOT/vcpkg" install --triplet x64-linux
cmake -S . -B build -G "Ninja Multi-Config" \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DVCPKG_INSTALLED_DIR="$PWD/vcpkg_installed" \
  -DVCPKG_TARGET_TRIPLET=x64-linux -DVCPKG_MANIFEST_INSTALL=OFF
cmake --build build --config Release
ctest --test-dir build -C Release --output-on-failure
```

On Windows use `x64-windows` (shared) or `x64-windows-static`; on Apple Silicon use
`arm64-osx`. Adapt shell paths to PowerShell if needed. No boilerplate CMake
modules or overlay ports are needed by the consumer. The Release's attached
`registry-consumer.zip` already contains a configuration pinned to the tested
registry commit.

### Validation and publishing

The `vcpkg registry` GitHub Actions workflow checks every PR and main/master push.
It verifies the version database against actual committed Git trees, bootstraps
the pinned vcpkg revision, installs both ports from a Git registry with binary
caching disabled, and builds/runs the external consumer in Debug and Release.
The six jobs cover Windows, Linux and macOS with both static and shared linkage.
For PRs the registry points to the local Git checkout, so unpublished PR
commits work; package sources still download from the pinned upstream commit.
Only shared triplet definitions are overlays, never the ports themselves.

After committing the ports and version files, run:

```sh
cmake -P scripts/Registry.cmake
```

Push the changes, then manually run **vcpkg registry** on main/master with
**publish** enabled. After all six jobs pass, it creates `v1.0.0` at the pinned
source commit and publishes a GitHub Release with the consumer archive and the
tested registry baseline in its notes. It rejects an existing tag pointing to
different sources and never moves tags. Ordinary PR/push runs do not publish.
Re-publishing an existing Release fails instead of silently replacing it.

Registry validation, consumer preparation, release notes and ZIP creation use
CMake and Git; no Python interpreter is required. `ACTION=prepare` defaults to
the local checkout and its `HEAD` when `REPOSITORY` and `BASELINE` are omitted.
The workflow uses shell for orchestration and `gh` only for publishing. To check
the release archive locally without publishing:

```sh
cmake -DACTION=release -DOUTPUT=/tmp/registry-release \
  -DRELEASE_REPOSITORY=cpp20120/cmake_boilerplate -P scripts/Registry.cmake
```

### Subsequent versions

1. Commit the library sources with the new CMake project version. Fetch that
   commit's GitHub archive and calculate its SHA512 (`vcpkg hash archive.tar.gz
   SHA512`). Update `vcpkg/release.json` and both release ports with real values.
2. Update each port's `version`. For packaging-only changes, retain the source
   version and increment the port's `port-version` instead.
3. Commit `ports/`, then append version entries using the official command:

   ```sh
   "$VCPKG_ROOT/vcpkg" x-add-version library1 \
     --x-builtin-ports-root="$PWD/ports" \
     --x-builtin-registry-versions-dir="$PWD/versions"
   "$VCPKG_ROOT/vcpkg" x-add-version library2 \
     --x-builtin-ports-root="$PWD/ports" \
     --x-builtin-registry-versions-dir="$PWD/versions"
   ```

4. Commit `versions/`, run `cmake -P scripts/Registry.cmake`, and push. Never
   replace historical version entries or their Git trees. Use the resulting
   registry commit as the consumer baseline; it cannot be embedded in itself.
5. Run the publishing workflow for a new source release. Packaging-only revisions
   use the new registry baseline and retain the existing source tag/Release.

The project generator deliberately excludes this repository's published registry
identity and release workflow. Generated applications retain local development
overlays; a new library publisher must establish its own source pins and history.

## Shared-library triplets

| Platform | Triplet | Configure/build preset |
| --- | --- | --- |
| Linux x64 | `x64-linux-boilerplate-shared` | `vcpkg-linux-shared` |
| Windows x64 (MSVC) | `x64-windows-boilerplate-shared` | `vcpkg-windows-shared` |
| macOS Intel | `x64-osx-boilerplate-shared` | `vcpkg-macos-x64-shared` |
| macOS Apple Silicon | `arm64-osx-boilerplate-shared` | `vcpkg-macos-arm64-shared` |

Run `cmake --preset <preset>` followed by `cmake --build --preset <preset>`
on the corresponding platform. Windows requires an x64 Visual Studio developer
shell (or an IDE-configured MSVC environment). macOS requires Xcode command-line
tools; each macOS preset selects a single matching application/dependency
architecture, overriding the inherited universal-binary setting.

All these triplets request shared dependencies and build both Debug and Release
packages. Windows uses the dynamic MSVC runtime. See the official
[triplet variables](https://learn.microsoft.com/en-us/vcpkg/users/triplets).
