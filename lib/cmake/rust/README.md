# Optional Cargo backend (Stages 1–3A.1)

CMake owns the build graph and project lifecycle. Cargo owns Rust dependency
resolution, crate compilation, fingerprints and incremental rebuilds. Including
`Boilerplate.cmake` does not search for or execute Rust tools. Only the explicit
`rust` project capability enables discovery; even `full` does not enable Rust.
Requirements: CMake 3.26+, Cargo and rustc 1.74+ from one native installation.

## Public API

```cmake
cmake_minimum_required(VERSION 3.26)
project(mixed LANGUAGES CXX) # LANGUAGES NONE is also usable for a Rust-only root
include(CTest)
include(path/to/Boilerplate.cmake)
boilerplate_project(CAPABILITIES rust testing)

boilerplate_add_rust_executable(my_tool
  MANIFEST rust/Cargo.toml
  KIND bin CARGO_TARGET my-tool
  PACKAGE my-package
  FEATURES cli
  NO_DEFAULT_FEATURES LOCKED
  RUSTFLAGS -Dwarnings)

boilerplate_add_rust_test(my_rust_tests TARGET my_tool
  LABELS unit TIMEOUT 120 TEST_ARGS --nocapture)
add_custom_target(run_my_tool COMMAND "$<TARGET_FILE:my_tool>" VERBATIM)
boilerplate_finalize_project()
```

`boilerplate_add_rust_executable(<target> ...)` accepts:

| Argument | Meaning |
| --- | --- |
| `MANIFEST <path>` | Required Cargo.toml, relative to the calling source directory or absolute |
| `KIND bin\|example` | Defaults to `bin`; examples must have executable crate type |
| `CARGO_TARGET <name>` | Cargo binary/example name, defaulting to the CMake target name |
| `PACKAGE <name>` | Workspace member; can be omitted if exactly one executable matches |
| `FEATURES <list>` | Cargo features as a CMake list |
| `NO_DEFAULT_FEATURES` | Pass `--no-default-features` consistently |
| `RUSTFLAGS <list>` | Explicit rustc arguments, encoded without whitespace splitting |
| `LOCKED`, `OFFLINE` | Corresponding Cargo build/test flags |
| `DEPENDS <list>` | CMake targets/files needed before Cargo, such as generated sources |
| `EXCLUDE_FROM_ALL` | Omit the Cargo build from the default build |

The function validates the executable using `cargo metadata --no-deps` at
configure time. Cargo.toml changes trigger reconfiguration; source changes are
Cargo's responsibility. Unknown API arguments are errors. A workspace package's
`rust-version` is checked against the selected compiler.

The target is a global `IMPORTED EXECUTABLE`. Build it through `<target>_cargo`
or a consuming CMake target; imported targets themselves are not command-line
build targets. `add_dependencies(consumer my_tool)`, CMake commands using the
target name, and `$<TARGET_FILE:my_tool>` follow its Cargo build dependency.
The executable is also declared as a byproduct for file-level dependencies.
Cargo runs on every requested build so it can detect source, manifest, build
script and dependency changes. An unchanged build normally reports `Finished`
without recompiling; Cargo controls incremental compilation within its profiles.

`boilerplate_add_rust_test(<name> TARGET <rust-target> [TIMEOUT <seconds>]
[LABELS <list>] [TEST_ARGS <list>])` creates one CTest entry running
`cargo test --all-targets` for the selected package. This covers unit and
integration tests and Cargo's test-enabled binaries/examples, not doctests.
It also creates `<name>_cargo_tests` (`cargo test --no-run --all-targets`) and
adds it to the existing `boilerplate_tests`, `boilerplate_check`, and `check`
workflow. It requires the `testing` capability and respects `BUILD_TESTING=OFF`.
Tests inherit the executable's toolchain, package, features, flags, profile,
target triple, working directory and artifact directory; these cannot diverge
through test registration. The CTest entry removes native compiler environment
variables (CC, CXX, AR, CFLAGS, CXXFLAGS, LDFLAGS) **only if they were absent from the Cargo target's
captured build-environment fingerprint**, preventing test-launcher-only additions from changing the
Cargo build variant. Variables captured in the target's build environment and other tracked
Cargo/Rust environment overrides are still checked by the fingerprint guard.
Build before invoking CTest so CMake prerequisites and standalone executable
tests are ready. CTest's Cargo suite also checks
freshness itself. Cargo serializes concurrent access to a shared target directory.

## Toolchain selection

By default, the first Cargo on PATH is selected and rustc is sought **beside it**.
There is no independent PATH fallback for rustc. Rustup proxies (including
hard-linked proxies) are resolved using `rustup which` in the CMake source root.
Thus root `rust-toolchain.toml` selection applies when the selected Cargo is a
rustup proxy; nested crate overrides do not subsequently change pinned tools.

Choose either an installed rustup toolchain:

```sh
cmake -S lib/tests/cmake/rust -B out/rust -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DBOILERPLATE_RUST_TOOLCHAIN=stable
```

or absolute tool paths:

```sh
cmake -S lib/tests/cmake/rust -B out/rust-system -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DBOILERPLATE_RUST_CARGO=/usr/bin/cargo \
  -DBOILERPLATE_RUST_RUSTC=/usr/bin/rustc
```

Supplying just one path finds the companion in that directory. Toolchain-name
and path overrides are mutually exclusive. No toolchain is installed/downloaded
by discovery. Both resolved tools must share an installation directory, host
triple and major/minor release; discovery reports both versions and the sysroot,
and checks that the host standard library exists. Split installations/custom
wrappers are deliberately rejected in this stage. Reconfigure to select changed
tools. Rustup updates may replace binaries in place; Cargo detects that on build.

Build/test commands pin Cargo, `RUSTC`, `RUSTDOC` and the tool directory. Explicit
`RUSTFLAGS` become `CARGO_ENCODED_RUSTFLAGS`, overriding ambient/config rustflags;
ambient Rust compiler wrappers are disabled. This follows Cargo's documented
[environment controls](https://doc.rust-lang.org/cargo/reference/environment-variables.html).
Cargo's normal dependency caches, registry credentials, linker configuration and
manifest profile settings remain Cargo-owned. Dependency caches may live outside
the build tree. Generated build artifacts and intermediate files stay beneath
`<CMAKE_BINARY_DIR>/cargo/<target>-<identity>/<Debug|Release>/`.

## Configurations and policies

Debug selects Cargo `dev`; Release selects Cargo `release`; RelWithDebInfo
selects an optimized Cargo `release` build with debuginfo (Stage 2B).
Artifacts are separated by CMake target, toolchain identity, feature/flag set,
host triple and effective configuration. Cargo uses an explicit host `--target`; Windows
paths include `.exe`, Linux/macOS paths do not. Empty build types, MinSizeRel and unsupported custom CMake configurations are rejected, without
changing the consuming project's CMake configuration list.

```sh
cmake -S lib/tests/cmake/rust -B out/rust-multi -G "Ninja Multi-Config" \
  '-DCMAKE_CONFIGURATION_TYPES=Debug;Release'
cmake --build out/rust-multi --config Debug --target run_rust check
cmake --build out/rust-multi --config Release --target run_rust check
ctest --test-dir out/rust-multi -C Release --output-on-failure
```

C++-specific policies and CMAKE_CXX_FLAGS are not translated to Rust.
Supported Rust build-profile policies are lowered independently, including
ASan/TSan with an opt-in nightly toolchain (Stage 3A.1). These also retain
their original semantics for C++ targets in a mixed project. Calling the C++ policy API on a Rust import is an error. Rust metadata
lives on the import in `BOILERPLATE_RUST_*` properties: `MANIFEST`, `PACKAGE`,
`KIND`, `CARGO_TARGET`, `FEATURES`, `NO_DEFAULT_FEATURES`, `FLAGS`, `TARGET_DIR`,
`BUILD_TARGET`, `CARGO`, `RUSTC`, `CARGO_VERSION`, `RUSTC_VERSION`, `HOST`, `SYSROOT`.
Imports follow the existing treatment of imported targets: they are not enrolled
in the C++ component/diagnostics target scan. Registration must precede project
finalization. Cross compilation and macOS explicit/universal architecture lists
are rejected in stage 1.

## Quality and fixture verification

Every registration supplies `<target>_format`, `<target>_format-check` and
`<target>_clippy`, plus `rust-format`, `rust-format-check` and `rust-clippy`
aggregates. Formatting uses the selected package; Clippy uses `--all-targets`
and the same build context, with `-D warnings`. Tools must exist beside selected
Cargo; missing rustfmt/Clippy produces an installation hint only when that quality
target is invoked. Ordinary builds need neither component nor nightly.

From the repository root:

```sh
cmake -S lib/tests/cmake/rust -B out/rust-debug -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build out/rust-debug --target run_rust copy_rust check
ctest --test-dir out/rust-debug --output-on-failure
cmake --build out/rust-debug --target rust-format-check rust-clippy

cmake -DCHECK_BINARY=/tmp/boilerplate-rust-check -DCHECK_QUALITY=ON \
  -P lib/tests/cmake/verify_rust.cmake
cmake -DCHECK_BINARY=/tmp/boilerplate-rust-multi-check \
  '-DCHECK_GENERATOR=Ninja Multi-Config' -P lib/tests/cmake/verify_rust.cmake
```

The fixture also has local `rust-debug`, `rust-release`, `rust-multi` and
`cpp-only` configure presets: run `cmake --preset rust-debug`,
`cmake --build --preset rust-debug` and `ctest --preset rust-debug` from
`lib/tests/cmake/rust`. The existing standalone library build exposes the explicit
`boilerplate_check_rust` regression target, which is not a dependency of C++ checks.
The regression script accepts `CHECK_GENERATOR`, `CHECK_QUALITY` and
`CHECK_RUST_TOOLCHAIN` / `CHECK_RUST_CARGO` / `CHECK_RUST_RUSTC` overrides.

The fixture has no external dependencies. Checks cover disabled Rust with absent
tools, tool diagnostics, imports, dependencies and file byproducts, paths/flags
with spaces, unchanged-build freshness, source-change recompilation, CTest,
Debug/Release isolation, policy rejection and lifecycle ordering.

## Benchmarks and scenarios

Stage 2A enables Rust imports in the existing `boilerplate_add_harness()` and
`boilerplate_add_scenario()` APIs. See the [benchmark guide](../benchmark/README.md#rust-executables-and-backend-provenance-stage-2a)
for registration examples, backend metadata, new provenance properties and
`verify_rust_benchmarks.cmake` acceptance checks. Both runners use the same imported
artifact and Cargo dependency; no C++ target policies are applied to Rust.
Rust scenario `PGO` is explicitly rejected until a later stage.

## Subsequent stages

Coverage, PGO, packaging and DagFlow-Rust migration are deferred.
Rust ASan/TSan are implemented in Stage 3A.1, and cargo-fuzz in Stage 3A.2 below. Backend-specific benchmark metadata is implemented in Stage 2A using
the existing CMake benchmark and scenario runners.
No second benchmark runner or xtask orchestration is introduced. Rust libraries,
C++/Rust FFI, cross compilation, doctest orchestration and broad CI expansion are
also outside this stage. Platform path handling is implemented, but macOS,
Windows, Visual Studio and Xcode require verification on those hosts.

## Stage 2B: profiles and target-local Cargo variants

The CMake build orchestrator now supports `Debug`, `Release` and
`RelWithDebInfo` for Cargo targets. `RelWithDebInfo` selects the release Cargo
profile with an explicit `opt-level=3` and `debug=2` override. The corresponding
output directory remains Cargo's `release` subdirectory; the outer CMake build
variant gets its own unique `CARGO_TARGET_DIR`.

```cmake
boilerplate_define_policy(rust-fast RUST_OPT_LEVEL 3 LTO_MODE thin
  RUST_CODEGEN_UNITS 1 FRAME_POINTERS ON)

boilerplate_add_rust_executable(rust_fast
  MANIFEST rust/Cargo.toml KIND bin CARGO_TARGET my-bench PACKAGE my-crate
  FEATURES scheduler NO_DEFAULT_FEATURES LOCKED
  POLICIES rust-fast)

boilerplate_add_rust_executable(rust_small
  MANIFEST rust/Cargo.toml KIND bin CARGO_TARGET my-bench PACKAGE my-crate
  FEATURES scheduler NO_DEFAULT_FEATURES LOCKED
  POLICY_OPTIONS RUST_OPT_LEVEL z LTO_MODE off)
```

`POLICIES` reuses the existing named-policy composition. `POLICY_OPTIONS`
accepts explicit KEY VALUE pairs and overrides named policies. The per-target
`PROFILE` argument selects one named `BOILERPLATE_PROFILE` for that Rust import;
`RUST_CARGO_PROFILE` selects the actual Cargo profile (`dev`, `release` or a
profile defined by the manifest). Target options never mutate `Cargo.toml`.

| Setting | Effect on Cargo/Rust |
| --- | --- |
| `RUST_OPT_LEVEL` | `CARGO_PROFILE_<PROFILE>_OPT_LEVEL` (`0,1,2,3,s,z`) |
| `LTO_MODE` | profile LTO (`thin`, `fat`, `off`, `inherit`) |
| `RUST_DEBUG_INFO` | profile debuginfo (`0,1,2`, line-level options) |
| `RUST_CODEGEN_UNITS` | profile codegen units, positive integer |
| `RUST_INCREMENTAL` | profile incremental boolean |
| `ENABLE_NATIVE` | `-C target-cpu=native`, or `generic` for explicit OFF |
| `FRAME_POINTERS` | `-C force-frame-pointers=yes/no` |
| `DEBUG_SYMBOLS` | convenience mapping to profile debug `2/0` |
| `RUST_CARGO_PROFILE` | actual Cargo profile name |
| `RUST_TARGET` | native host target triple only (cross compilation deferred) |

All Rust-specific default cache values (`BOILERPLATE_RUST_*`) are `inherit`,
which does **not** override manifest Cargo profiles. Explicit enabled common
project defaults for LTO/native/frame-pointers/debug symbols also map to Rust;
neutral C++ defaults do not erase Cargo settings. Unsupported C++ keys,
including CUDA, Unity, CFI, MSVC-specific hardening and C++ standards, fail
explicitly when requested for Rust. PGO/coverage remain separate future work; sanitizers and fuzzing are
implemented below.

A variant is fingerprinted from the Cargo workspace and package, requested
features (normalized), profile, emitted rustc flags, toolchain/host, relevant
Cargo configurations and build environment. The CMake registration name is
also included so that two imported producers never declare duplicate Ninja
byproducts, even if their desired Cargo configuration is identical. This trades
some cache reuse for a correct independently owned CMake build graph; Cargo
still retains incremental compilation within each variant. Outputs live under
`<CMAKE_BINARY_DIR>/cargo/<sha256>/<triple>/<profile>/` and can coexist.

Cargo and its `--target` option manage actual compilation. CMake uses profile
environment overrides for Cargo-owned settings and encoded rustc flags only for
non-profile options. If this would discard user Cargo config rustflags, the
integration rejects the combination instead of silently overriding it. Build,
test, quality checks and benchmarks inherit the same build-variant config.
A change to the tracked Rust build environment requires CMake reconfiguration.

Verify Stage 2B (requires a real native Cargo/rustc installation):

```sh
cmake -DCHECK_BINARY=/tmp/boilerplate-rust-profiles \
  -P lib/tests/cmake/verify_rust_profiles.cmake
cmake -DCHECK_BINARY=/tmp/boilerplate-rust-profiles-multi \
  '-DCHECK_GENERATOR=Ninja Multi-Config' \
  -P lib/tests/cmake/verify_rust_profiles.cmake
```

C++-only projects still require no Rust toolchain. Rust cross targets, PGO,
other sanitizers, platform-specific link options and Cargo profile inheritance
beyond Cargo's normal semantics are not implemented. The Stage 2B suite
exercises real builds when a Rust toolchain is present.

## Stage 3A.1: Rust ASan and TSan (Linux x86_64)

Stage 3A.1 supports Rust `address` and `thread` sanitizers on
`x86_64-unknown-linux-gnu` **only**, using matching **nightly** Cargo/rustc
and the `rust-src` component. Configure-time checks fail explicitly for stable
Rust, missing `rust-src`, unsupported host targets, and other sanitizer modes
(`undefined`, `address-undefined`, `leak`); there is no invented equivalent
of C++ UBSan or LSan. Rust-only projects continue to support `LANGUAGES NONE`.

Choose a nightly toolchain **before** configuring a Rust project:

```sh
rustup toolchain install nightly --component rust-src
cmake -S your-project -B out/rust-asan -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DBOILERPLATE_RUST_TOOLCHAIN=nightly \
  -DBOILERPLATE_RUST_SANITIZER=address
cmake --build out/rust-asan --target your_rust_target_cargo your_rust_test_cargo_tests
ctest --test-dir out/rust-asan -C Debug --output-on-failure
```

`BOILERPLATE_RUST_SANITIZER=inherit` (default) uses the existing project-wide
`BOILERPLATE_SANITIZER` (default `none`). For mixed projects, use the
Rust-specific cache setting or a **target-specific** policy to avoid altering
C++ compilation. Both the existing `asan`/`tsan` named policies and
`POLICY_OPTIONS SANITIZER address|thread|none` are supported:

```cmake
boilerplate_add_rust_executable(my_asan
  MANIFEST Cargo.toml PACKAGE my-crate CARGO_TARGET my-bin
  POLICY_OPTIONS SANITIZER address)
boilerplate_add_rust_test(my_asan_tests TARGET my_asan LABELS sanitizer)

boilerplate_add_rust_executable(my_tsan
  MANIFEST Cargo.toml PACKAGE my-crate CARGO_TARGET my-bin
  POLICIES tsan)
boilerplate_add_rust_test(my_tsan_tests TARGET my_tsan LABELS sanitizer)
```

Each sanitizer uses `-Zsanitizer=address|thread` in
`CARGO_ENCODED_RUSTFLAGS` and passes `-Zbuild-std` to Cargo (including
`cargo test` and test prebuilding). The explicit `--target` ensures that host
build scripts/proc-macros are distinct from the instrumented target code.
The stdlib is rebuilt with the same instrumentation; this can take longer
on a fresh variant. Raw `-Zsanitizer` in user RUSTFLAGS is rejected to keep
variant identity and provenance consistent. Each variant has an isolated
Cargo artifact directory; sanitizers never reuse unsanitized executables.

`RunCargo.cmake` also enforces the configured native build environment when
invoked by Ninja or CTest. If `CC`, `CXX`, `AR`, `CFLAGS`, `CXXFLAGS`, or
`LDFLAGS` were absent when the Cargo variant was registered, unexpected values
injected by a later launcher are removed before fingerprint validation **and**
Cargo execution. If any of these were present during configuration, their
values remain fingerprinted and changes fail. Rust-specific environment inputs
(e.g. `RUSTFLAGS`, Cargo profile overrides) remain strictly validated. To
intentionally use a different native compiler for build scripts, set it before
reconfiguring CMake so the new build variant records the change.

`boilerplate_collect_target_metadata()` reports `rust_sanitizer`, and the
sanitizer is incorporated into the build identity. `boilerplate_add_harness()`
and `boilerplate_add_scenario()` remain available, but sanitizer overhead
means instrumented results are **not comparable to production benchmarks**.
Rust PGO is not yet available. Rust fuzzing is implemented in Stage 3A.2.
This stage does not promise that
all Rust concurrency bugs are detectable by TSan; a real instrumented test
run is still required.

A toolchain-free regression test uses fake Cargo/rustc drivers to validate
the CMake orchestration, sanitizer flags, artifact separation, test execution,
and diagnostic failures:

```sh
cmake -S lib -B out/build -G Ninja
cmake --build out/build --target boilerplate_check_rust_sanitizers
# Or the standalone CMake-script test:
cmake -DCHECK_BINARY=/tmp/boilerplate-rust-asan-check \
  -P lib/tests/cmake/verify_rust_sanitizers.cmake
```

**These fake-driver tests do not run the Rust sanitizers themselves.** The real
nightly Cargo/rustc sanitizer build and runtime tests must also pass on a
Linux x86_64 host before enabling sanitizer CI for actual projects. macOS,
Windows, other host triples, Rust cross-compilation, sanitizer-specific
runtime options, and fuzzing integration are outside Stage 3A.1.

## Stage 3A.2: Rust cargo-fuzz integration (Linux x86_64)

Rust fuzzing is **not** an imported Cargo executable: `cargo-fuzz` supplies
libFuzzer, sanitizer coverage, and the fuzz binary's lifecycle. The optional
Rust capability exposes a dedicated adapter to the same CMake build / CTest
orchestration, without making up `$<TARGET_FILE:...>` for a fuzz target.

Install `cargo-fuzz` and an LLVM nightly toolchain with Rust sources:

```sh
rustup toolchain install nightly --component rust-src
rustup run nightly cargo install cargo-fuzz --locked
```

When a system-installed `cargo` does not support `cargo +nightly`, use `rustup run nightly cargo ...`; the CMake runner pins nightly Cargo for nested `cargo-fuzz` invocations regardless of the system Cargo on PATH.

`cargo-fuzz` also requires a native C++ compiler. Current integration is limited
to Linux `x86_64-unknown-linux-gnu`, and sanitizer `address` (default) or
`none`. It explicitly rejects stable Rust, missing `rust-src`, missing
`cargo-fuzz`, missing fuzz targets and unsupported sanitizer combinations.
Configure with `-DBOILERPLATE_RUST_TOOLCHAIN=nightly`, or select matching
nightly Cargo/rustc paths. Optional `BOILERPLATE_RUST_CARGO_FUZZ` pins an
installed `cargo-fuzz` executable.

A dedicated Cargo fuzz package (usually `fuzz/Cargo.toml`) must already exist,
for example created using `cargo fuzz init`; the CMake integration never
modifies manifests or creates Rust targets:

```cmake
project(MyRustFuzz LANGUAGES NONE)
include(CTest)
include("path/to/Boilerplate.cmake")
boilerplate_project(CAPABILITIES rust fuzzing)
boilerplate_add_rust_fuzzer(scheduler
  MANIFEST "${CMAKE_SOURCE_DIR}/fuzz/Cargo.toml"
  FUZZ_TARGET scheduler
  SEED_CORPUS "${CMAKE_SOURCE_DIR}/fuzz/seeds/scheduler"
  DICTIONARY "${CMAKE_SOURCE_DIR}/fuzz/dictionary.txt"
  RUN_SECONDS 60 TIMEOUT 15 MAX_LEN 4096
  FEATURES scheduler)
boilerplate_finalize_project()
```

Generated CMake targets:

- `scheduler_cargo_fuzz_build`: instrumented build (`cargo fuzz build`).
- `fuzz_scheduler`: bounded fuzz execution (`cargo fuzz run`).
- `replay_scheduler`: replay a single existing input, selected by the
  `BOILERPLATE_FUZZ_REPLAY_INPUT` environment variable.
- CTest `scheduler_smoke`: a bounded `-runs=1` smoke check (part of `check`).
- Existing `boilerplate_fuzzers` and `fuzz-smoke` aggregates when the project
  enables the `fuzzing` capability (which inherits `testing`).

```sh
cmake --build out/fuzz --target scheduler_cargo_fuzz_build
cmake --build out/fuzz --target fuzz_scheduler
cmake --build out/fuzz --target boilerplate_check
BOILERPLATE_FUZZ_REPLAY_INPUT=/absolute/path/to/crash-file \
  cmake --build out/fuzz --target replay_scheduler
```

`CORPUS` selects an explicit **mutable** directory. Alternatively,
`SEED_CORPUS` is a flat **read-only** seed directory; missing seed files are
copied to the build-tree `rust-fuzz/<name>/corpus` without overwriting existing
mutated corpus files. Crash artifacts live under
`rust-fuzz/<name>/artifacts/`. Both survive rebuilds. Explicit
`CORPUS` and `SEED_CORPUS` are mutually exclusive. `NO_SMOKE` permits a
non-testing project; `NO_DEFAULT_FEATURES`, `FEATURES`, `LABELS` and `DEPENDS`
are also supported. `SANITIZER none` disables ASan while retaining libFuzzer
coverage. No C++ policy is applied to Rust fuzz targets.

Fuzz build variants are isolated per CMake config, target, features, sanitizer,
manifest/lockfile hash, pinned tool hashes and captured build environment.
Debug uses cargo-fuzz `--dev`, Release its optimized default, and
RelWithDebInfo adds Cargo release debuginfo. The runner uses the original
Rust environment fingerprint, including native compiler normalization, but
rejects changed Rust flags rather than silently changing instrumentation.
Ambient `RUSTFLAGS`/`CARGO_ENCODED_RUSTFLAGS` overrides are not yet supported
for this adapter. Existing `.cargo/config` rustflags and LLVM runtime-specific
options have not been exhaustively validated.

A self-contained fixture lives under `lib/tests/cmake/rust/fuzz/`; it includes
an actual `libfuzzer-sys` target for optional real-toolchain validation.
Toolchain-free orchestration checks use fake Cargo and cargo-fuzz binaries:

```sh
cmake -S lib -B out/build -G Ninja
cmake --build out/build --target boilerplate_check_rust_fuzz
# Real nightly test (requires network-resolved libfuzzer-sys):
cmake -S lib/tests/cmake/rust/fuzz -B out/rust-fuzz -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug -DBOILERPLATE_RUST_TOOLCHAIN=nightly
cmake --build out/rust-fuzz --target scheduler_fuzz_cargo_fuzz_build
ctest --test-dir out/rust-fuzz -C Debug -R scheduler_fuzz_smoke --output-on-failure
```

Fake drivers validate command construction, persistence, environment gating,
variant separation and CTest, **not** actual LLVM coverage or the runtime's
ability to detect crashes. Real fuzzing, non-Linux targets and fuzz coverage
reports require independent validation. Rust coverage and PGO are deferred.
