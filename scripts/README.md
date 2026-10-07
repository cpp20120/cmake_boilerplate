# Native host setup

The installers are Bash 3.2+ on Linux/macOS and Windows PowerShell 5.1+ / PowerShell
7 on Windows. They do not use Python, pip or a virtual environment. CMake and Ninja
are installed through the native package manager.

Linux / macOS:

```sh
./setup-host.sh --dry-run
./setup-host.sh --install
source out/host-tools/env.sh
./setup-host.sh --check
cmake --preset app-debug
cmake --build --preset app-debug
```

Windows:

```powershell
.\setup-host.ps1 --dry-run
.\setup-host.ps1 --install
. .\out\host-tools\env.ps1
.\setup-host.ps1 --check
cmake --preset vcpkg-windows-shared
cmake --build --preset vcpkg-windows-shared
```

`--dry-run` prints commands without installing packages or writing files.
`--check` reports missing native tools and returns nonzero if setup is incomplete.
`--install` may request sudo/UAC. No shell startup files are edited.

## Prerequisites and package managers

- Debian/Ubuntu: apt, with native compiler/build prerequisites installed by setup.
- Fedora: dnf, including its `repoquery` command for dependency checks.
- Arch: pacman. Update your system normally first; setup does not refresh Arch
  databases independently or perform a full system upgrade.
- macOS: existing [Homebrew](https://brew.sh) and Xcode Command Line Tools
  (`xcode-select --install`). The system Bash can run setup. The activation file
  exposes Homebrew LLVM tools on PATH.
- Windows: existing [winget / App Installer](https://learn.microsoft.com/en-us/windows/package-manager/winget/).
  Setup installs the Visual Studio 2022 C++ Build Tools workload and recommended
  SDK components, or adds the workload to an existing Visual Studio installation.
  Finish any requested reboot. Activation enters the x64 VS developer shell.

If PowerShell execution policy blocks the script, launch it with
`powershell -ExecutionPolicy Bypass -File .\setup-host.ps1 --install`; activate
`env.ps1` in a shell with an appropriate execution policy.

## Tools

The shared package matrix is [host-tools.txt](host-tools.txt). It covers Git,
CMake (CTest/CPack), Ninja, Clang, clangd, clang-tidy, clang-format, LLD, ccache,
sccache, cppcheck, Clazy, LLVM coverage/PGO tools, lcov/genhtml, Doxygen, Graphviz,
shader compilers, platform packaging tools and Unix fuzzing backends. Windows
shader tools use the Vulkan SDK package; packaging uses NSIS. Linux adds patchelf
and RPM tools. Unsupported native tools are marked `N/A`.

CMake must be at least 3.26. An older distribution package is reported as incomplete;
upgrade through your package manager or install an official native CMake release.
There is no pip fallback. Existing executable paths are reused, so setup is not a
global upgrade command. Package versions are selected by the configured repositories.

The Unix installer checks package-manager dependency metadata before installation.
A transaction/dependency closure containing Python or libpython is skipped and
reported as incomplete. This also applies to native tools whose distribution
package bundles Python-dependent helpers. DNF and Homebrew checks are conservative:
they may skip a tool even when that Python dependency is already installed.
If metadata cannot be checked, the package is skipped. Required dependencies are
never bypassed with `--nodeps`. apt recommendations and DNF weak dependencies are
disabled. Review the reported tool and provision a suitable native distribution
separately if the host must remain Python-free.

Package errors do not prevent attempts to install the remaining tools. The final
exit status is nonzero if a package failed, was skipped or an expected tool is
missing. `--dry-run` prints the intended package commands without querying full
dependency metadata; it does not certify that every package can be installed.

## Python is a separate, optional workflow

The process harness is still implemented in Python. Normal builds and host setup
do not require it. Install Python 3 yourself only if you need the harness, then run:

```sh
./setup-host.sh --check-harness
```

```powershell
.\setup-host.ps1 --check-harness
```

This mode checks an existing interpreter and prints its version. It installs
nothing; missing Python is an error only for this separate check. The ordinary
`--check` does not invoke Python. See [the harness documentation](../lib/cmake/harness/README.md).

`cmake-format`, `gcovr`, the `iwyu_tool` runner and Emscripten also need Python;
they are outside host setup and are listed as separate tools. The former
`--with-emscripten` flag has been removed. Provision those workflows separately
if you choose to install Python. No Python harness source files were changed.

## SDKs and libraries

CUDA and standalone DXC are detected but not installed automatically. Use their
vendor installers if those capabilities are needed. Drivers remain OS-managed.
Qt, Vulkan/OpenGL libraries, GoogleTest, RapidCheck and Google Benchmark are project
dependencies managed by vcpkg manifest features/presets. Installing a particular
port may have its own host-tool dependencies; that is separate from host setup.

## Locations and repeat runs

- vcpkg defaults to `$VCPKG_ROOT` or `~/vcpkg`. Override with
  `--vcpkg-root /path/to/vcpkg`. Existing checkouts are reused without pulling or
  resetting. A new checkout uses the upstream default branch.
- The repository's `vcpkg/` contains overlays and is rejected as a checkout path.
- Activation files live in `out/host-tools`; override with `--tools-dir PATH`.
- The previous Python setup's venv, if present, is no longer used or placed on
  PATH. No existing user environments or Python installations are removed.
- Unix `--manager apt|dnf|pacman|brew` can inspect another platform's dry-run plan.
  Installation rejects a manager that does not match the host.

Offline tests also use only native shells:

```sh
bash scripts/test-setup-host.sh
```

```powershell
.\scripts\test-setup-host.ps1
```

The shell tests run with a minimal PATH containing no Python and mock package
managers. Neither test suite installs real packages. CI runs the native tests on
Linux, macOS and Windows.
