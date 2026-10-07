# Native host setup

The installers are Bash 3.2+ on Linux/macOS and Windows PowerShell 5.1+ / PowerShell
7 on Windows. They do not use Python, pip or a virtual environment. CMake and Ninja
are installed through the native package manager.

Linux / macOS:

```sh
./setup-host.sh --dry-run --profile dev
./setup-host.sh --install --profile dev
source out/host-tools/env.sh
./setup-host.sh --check
cmake --preset app-debug
cmake --build --preset app-debug
```

Windows:

```powershell
.\setup-host.ps1 -DryRun -Profile dev
.\setup-host.ps1 -Install -Profile dev
. .\out\host-tools\env.ps1
.\setup-host.ps1 -Check -Profile dev
cmake --preset vcpkg-windows-shared
cmake --build --preset vcpkg-windows-shared
```

`--dry-run` prints commands without installing packages or writing files.
`--check` reports missing native tools and returns nonzero if setup is incomplete.
`--install` may request sudo/UAC. No shell startup files are edited.

The root scripts and `scripts/setup-host.sh` / `scripts/setup-host.ps1` are equivalent
entry points. PowerShell accepts `-Install`, `-Check`, `-DryRun`, `-Profile`,
`-ToolsDir`, `-VcpkgRoot` and the older double-dash spellings.
The legacy `devenv_and_run.sh` and `docker_devenv.sh` now forward to this bootstrap;
they require an explicit mode and no longer configure editors, shells or repositories.

| Profile | Capabilities |
| --- | --- |
| `minimal` | Git, CMake >= 3.26, Ninja, native C++ compiler, vcpkg and Unix port-build prerequisites |
| `dev` (default) | Minimal plus editor, analysis, cache, PGO/coverage, docs, shader, packaging and fuzzing tools |
| `ci` | Dev without clangd, clang-format, Clazy, docs and fuzzing tools |

Profiles select rows from the same table on both platforms. Unsupported packages
are marked `N/A`; `compiler` means the native C++ toolchain (Visual Studio on Windows,
Xcode command-line tools on macOS). Every audit reports `ALREADY`, `INSTALLED`, and
`MISSING`, followed by counts. CMake versions below 3.26 count as missing. Install
requests only missing/outdated tools, reuses vcpkg, and audits again afterwards.
A fully provisioned repeat run makes no package-install or vcpkg-bootstrap calls.
Activation files are regenerated; source them explicitly in the current shell.

OS/distribution and selected package manager are printed before the plan. Setup
does not add package repositories, change login shells, or edit persistent PATH.
It prints installation commands before running them. Install mode explicitly
authorizes package-manager transactions; check and dry-run do not mutate the host.

## Prerequisites and package managers

- Debian/Ubuntu: apt, with native compiler/build prerequisites installed by setup.
- Fedora: dnf.
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

Bootstrap does not require Python or explicitly invoke/install it. Transitive
dependencies are handled by the system package manager; a native tool package may
bring Python as a dependency. apt recommendations and DNF weak dependencies are
disabled, but required dependencies are not filtered.

Package errors do not prevent attempts to install the remaining tools. The final
exit status is nonzero if a package failed or an expected tool is missing.
`--dry-run` prints the intended commands; it does not certify that every package
can be installed.

## Python is a separate, optional workflow

The process/benchmark harness is implemented in CMake. Host setup, normal builds,
CTest, PGO, install/package and generated checks do not require Python. Install
Python 3 separately only for optional statistics/comparison tooling. Bootstrap does
not discover or check Python.

`cmake-format`, `gcovr`, the `iwyu_tool` runner and Emscripten also need Python;
they are outside host setup and are listed as separate tools. The former
`--with-emscripten` flag has been removed. Provision those workflows separately
if you choose to install Python.

## SDKs and libraries

CUDA and standalone DXC are not installed automatically. Use their
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
