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
