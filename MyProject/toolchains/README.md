# Toolchains and cross compilation

Capabilities select project workflows; target policies select compile/link behavior.
Toolchains select the target platform, compiler and SDK before `project()`. There is
no `cross-compile` capability. The toolchain files contain no project capabilities,
test flags, sanitizer profiles or package-download logic.

| Configure/build/test preset | Toolchain | Prerequisites on the host |
| --- | --- | --- |
| `native-linux-clang` | `native-linux-clang.cmake` | Linux Clang/Clang++ |
| `linux-arm64` | `linux-aarch64.cmake` | `aarch64-linux-gnu-gcc/g++`, target libc/C++ runtime (e.g. Debian cross packages) |
| `windows-x64-from-linux` | `llvm-mingw-x64.cmake` | Linux-hosted LLVM-MinGW SDK; `LLVM_MINGW_ROOT` environment/cache path |
| `android-arm64` | `android-arm64.cmake` | NDK; `ANDROID_NDK_ROOT` or `ANDROID_NDK_HOME`; default API 24 |
| `wasm32-emscripten` | `wasm32-emscripten.cmake` | Activated Emscripten SDK; `EMSDK` |

These presets inherit `app-release` and build under `out/build/<preset>`. SDKs are
provisioned separately; `setup-host` does not install them. Native compiler selection
does not set `CMAKE_SYSTEM_NAME`. Cross files do not force `STATIC_LIBRARY`
try-compiles: missing target linkers/runtimes must fail compiler validation.

```sh
cmake --preset linux-arm64
cmake --build --preset linux-arm64
cmake --install out/build/linux-arm64 --prefix /tmp/my-arm64-install
# Enable packaging if needed; TGZ avoids a host-specific native package installer.
cmake --preset linux-arm64 -DENABLE_PACKAGING=ON
cmake --build --preset linux-arm64 --target package
```

Linux uses the cross GCC driver's standard runtime paths. A standalone SDK may pass
`-DCMAKE_SYSROOT=/path/to/target-root`. Target libraries, headers and packages use
target roots only. Host executables use the host search path. For package consumers,
use the same toolchain and add the staging prefix to `CMAKE_FIND_ROOT_PATH` (or use
`CMAKE_STAGING_PREFIX`); do not mix host dependency prefixes with target installs.

## Host tools and target execution

`boilerplate_find_host_program(result NAMES ... HINTS ...)` explicitly bypasses
sysroot redirection. Compiler launchers, clang-tidy, documentation/format tools,
shader compilers and LLVM profile tools are looked up on the host. A host codegen
tool can be imported into the target graph:

```cmake
boilerplate_add_host_tool(host_protoc NAMES protoc HINTS /opt/host-tools/bin)
add_custom_command(OUTPUT messages.pb.cc
  COMMAND host_protoc --cpp_out=${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/messages.proto
  DEPENDS messages.proto VERBATIM)
```

Build code generators separately with a native toolchain, then import their host
binaries. An executable compiled in the current cross build is a target artifact,
not a host tool. Explicit tool paths must point to host-compatible programs.

Without an emulator, ordinary target CTests are **disabled**, and GoogleTest
discovery does not run target binaries. Tests and benchmarks still compile.
Explicit scenario, harness and PGO training targets fail with an emulator diagnostic
instead of attempting host execution. With an emulator:

```sh
cmake --preset linux-arm64 '-DCMAKE_CROSSCOMPILING_EMULATOR=qemu-aarch64;-L;/usr/aarch64-linux-gnu'
cmake --build --preset linux-arm64
ctest --preset linux-arm64
```

The standard per-target `CROSSCOMPILING_EMULATOR` property is also supported.
Its list of command/arguments is forwarded to scenario, harness and PGO runners;
runtime command prefixes (such as taskset) stay outside the emulator. Set the
property before registering the scenario/harness. Emulated benchmark timings and
profiles describe emulated execution, not native device performance.

`ENABLE_NATIVE`/`-march=native` is rejected for cross targets. libFuzzer execution
requires an emulator; cross AFL/honggfuzz integration needs a backend-specific
runner and currently fails explicitly. Deployment runtime scanning remains disabled
for cross builds unless the existing explicit `NO_RUNTIME_DEPENDENCIES` path is used.
Cross package filenames include the target system and processor.

`boilerplate_add_reference()` forwards the toolchain, sysroot, root paths and
toolchain platform variables to its separate CMake build. Its `TEST` option requires
an emulator in cross builds.

## vcpkg

The supplied cross presets use the system provider. To combine a cross SDK with
vcpkg, create a user preset that overrides `toolchainFile` with the vcpkg toolchain,
sets `VCPKG_CHAINLOAD_TOOLCHAIN_FILE` to the corresponding file here, and selects
the matching `VCPKG_TARGET_TRIPLET` and native `VCPKG_HOST_TRIPLET`. Enable the vcpkg
provider explicitly. Do not use a host triplet for target dependencies; the SDK
toolchain alone does not load the vcpkg provider.

## Regression checks

```sh
cmake -DCHECK_BINARY=/tmp/cross-semantics -P lib/tests/cmake/verify_cross.cmake
cmake -DCHECK_BINARY=/tmp/cross-arm64 \
  -DCHECK_TOOLCHAIN="$PWD/toolchains/linux-aarch64.cmake" -DCHECK_ARCH=aarch64 \
  '-DCHECK_EMULATOR=qemu-aarch64;-L;/usr/aarch64-linux-gnu' \
  -P lib/tests/cmake/verify_cross.cmake
```

The first check deliberately uses the native compiler under cross semantics. It
checks configure/build/install/TGZ, exported-package consumers, ExternalProject,
host-vs-target lookup, blocked execution and an emulator prefix containing arguments.
It is not architecture validation. The second uses a real AArch64 SDK, checks the
ELF machine ID and optionally runs tests, scenarios, harness and PGO through QEMU.
CI provisions GCC/QEMU for that path. Windows/Android/Emscripten SDK builds require
their respective external SDKs and are not covered by this Linux regression job.

See the upstream [CMake toolchain guide](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
and [emulator property](https://cmake.org/cmake/help/latest/prop_tgt/CROSSCOMPILING_EMULATOR.html).
