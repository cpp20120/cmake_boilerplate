# Reusable CMake API

Recipes, knobs and preset commands are in the [root README](../README.md).
This directory is the **standalone library/core slice**. Copy `cmake/` into a
library or tool project, call `project()` and `include(CTest)`, then include
`cmake/Boilerplate.cmake` in the common parent directory. CMake 3.26+ is required.

The higher-level application/host/plugin execution model intentionally lives in
the repository-root `cmake/` layer and is not loaded by this slice. A library can
therefore be extracted, built, tested, installed and consumed without bringing
application hosting machinery with it.

## Targets

```cmake
boilerplate_add_library(my_math
  VERSION 1.2.0
  SOURCES src/math.cpp
  INCLUDE_DIR include
  PUBLIC_LIBRARIES Threads::Threads
  PRIVATE_LIBRARIES some_dependency
  PACKAGE_CONFIG cmake/MyMathConfig.cmake.in)

boilerplate_add_executable(my_tool
  SOURCES tools/main.cpp LIBRARIES my_math::my_math INSTALL)

boilerplate_add_test(my_test
  SOURCES tests/math.cpp LIBRARIES my_math::my_math
  ARGS --small LABELS math TIMEOUT 10
  ENVIRONMENT "MODE=test")

boilerplate_add_example(math_example
  SOURCES examples/math.cpp
  LIBRARIES my_math::my_math
  ARGS --demo
  SMOKE SMOKE_ARGS --quick
  PGO PGO_ARGS --training-size 100)
```

`boilerplate_add_example()` is sugar over the same executable/scenario/check/PGO
primitives used elsewhere. Every example joins the `boilerplate_examples` build
aggregate and the `examples` scenario group, so it gets `run_<target>` and the
shared `run_group_examples` runner. `SMOKE` adds a bounded CTest check; `PGO`
registers an optional training workload. Neither execution path is part of the
normal build. `INSTALL` is available when an example is also a shipped tool.

`VERSION`, library dependencies and `PACKAGE_CONFIG` are optional. The checked-in
`library1` and `library2` examples deliberately exercise different consumer-local
policy modules; `library2` additionally demonstrates a public `Threads::Threads`
dependency, a matching `find_dependency(Threads)` package config and PCH. The explicit
`boilerplate_check_cmake` target installs/relocates both examples to keep those paths
covered.

Export macros
are derived from the library name: `my_math_export.h`, `MY_MATH_EXPORT`,
`MY_MATH_STATIC_DEFINE`. Include the export header in public headers and annotate
exported functions/classes. Static/shared are real CMake library types. Aliases:
`my_math::shared`, `my_math::static`, `my_math::my_math` and build-tree `my_math`.
Per-library `<NAME>_BUILD_SHARED/STATIC` override global defaults; at least one is
required for each declared library. The preferred alias selects shared if available.

### Library/core boundary

`boilerplate_add_library()` and `boilerplate_add_executable()` are the reusable
core artifact APIs. The core also owns project capabilities, target policies,
shaders, workloads, testing and packaging primitives. It deliberately does not
define `boilerplate_add_application()`, `boilerplate_add_host()`,
`boilerplate_add_plugin()` or application deployment. Those are layered above
this directory by the full repository framework.

Installation puts each library's headers under `include/<name>`, exports native
artifacts and package configs, and propagates static instrumentation link requirements.
Start custom package configs from `LibraryConfig.cmake.in` and add dependencies with
`find_dependency()`. The examples expose distinct `<library1.hpp>` and
`<library2.hpp>` headers through their exported targets. Installed PGO/ThinLTO
artifacts may require matching compiler/profile inputs; plain release packages are
more portable.

For existing owned targets call `boilerplate_apply_target_policy(target)` in their
source directory. `boilerplate_apply_optimization(target)` is kept as a compatible
legacy name. Both apply the common project options once. Third-party imported/
FetchContent targets are not modified. `boilerplate_set_output_name` adds the
effective target artifact suffix. Dependencies still use ordinary CMake targets;
there is no separate dependency graph or custom package manager.

## Project capabilities and lifecycle

The `cuda` project capability enables CUDA; [CUDA target policies](cmake/docs/Cuda.md)
provide `cuda`, `cuda-debug`, `cuda-profiled`, `cuda-fast-math` and `runtime-cuda`.

The same reusable `cmake/` tree now covers whole-project concerns without turning them
into target flags. Include `Bootstrap.cmake` before `project()` when using its in-source
guard/dependency-provider bootstrap, then configure capabilities after `Boilerplate.cmake`:

```cmake
cmake_minimum_required(VERSION 3.26)
include(cmake/Bootstrap.cmake)
boilerplate_bootstrap()
project(server VERSION 1.0 LANGUAGES CXX)
include(CTest)
include(cmake/Boilerplate.cmake)

boilerplate_project(
  TOP_LEVEL_CAPABILITIES developer
  EMBEDDED_CAPABILITIES project-minimal)

boilerplate_add_executable(server SOURCES src/main.cpp
  POLICIES runtime-webserver)
boilerplate_finalize_project()
```

The composition unit is intentionally different at each level:

- bootstrap: toolchain/dependency provider and in-source guard, before `project()`;
- project capabilities: docs, analysis, tests, packaging, metadata and lifecycle workflows;
- target policies: warnings, hardening, sanitizer/LTO/PGO, runtime, Qt and graphics semantics;
- workloads: CTest/scenarios/PGO/Python harness.

Primitive project capabilities are `project-minimal`, `compile-commands`,
`compiler-cache`, `formatting`, `static-analysis`, `testing`, `property-testing`, `fuzzing`,
`coverage-report`, `docs`, `packaging`, `reproducible-build`, `build-info`,
`diagnostics`, `cuda`, and `web-deployment`. `developer`, `quality`, `distribution`,
`ci` and `full` are convenience compositions. Capabilities compose through configure and
finalize hooks, so a project-local module can define another capability with
`boilerplate_define_project_capability()` without adding a preset cross product.

`PROJECT_IS_TOP_LEVEL` selects the top-level or embedded capability list. This is the
important difference from a single developer-mode switch: an embedded library can remain
`project-minimal` while the standalone repository enables format/analyze/tests/docs.
Optional developer tools degrade to omitted custom targets unless
`BOILERPLATE_REQUIRE_PROJECT_TOOLS=ON`.

`build-info` creates an installed JSON manifest and the build-tree interface target
`boilerplate::build_info`; link it when C++ code needs version/revision/compiler metadata.
`distribution` enables reproducible source/debug path mapping as the project default and
component-aware CPack packaging (`Runtime`, `Development`, `Documentation`). A target can
still opt back out with `POLICIES minimal`. Coverage keeps instrumentation (`coverage`
target policy) separate from report generation (`coverage-report` project capability).

## Components and workspace scale

For large trees, keep one `boilerplate_project()` / `boilerplate_finalize_project()`
lifecycle and group subtrees with `boilerplate_add_component()`. The grouping is optional:
small library projects behave exactly as before. Targets created by the core helpers are
registered automatically for component ownership. Analysis/diagnostics still inspect the
complete CMake target graph; finalization freezes and caches that graph so multiple hooks
do not repeatedly walk a hundred-directory build tree.

A subtree that is also a standalone repository can call `boilerplate_component()` only in
its top-level branch; when embedded, the parent's `boilerplate_add_component()` supplies
the inherited component identity. Components do not own separate capabilities or target
policy defaults.

## Target policies and composition

`BOILERPLATE_PROFILE` remains a **project/configuration default** used by presets
(build type and default LTO/PGO choices). It is not the composition axis. The
composition unit is a CMake target. Named target policies can reset or override the
project defaults independently for each library/executable:

```cmake
# A domain policy for a scheduler/runtime. Policies listed in INHERITS compose
# left-to-right, so later entries win.
boilerplate_define_policy(runtime
  INHERITS minimal native thin-lto lld gc-sections no-plt)

boilerplate_add_library(my_runtime
  SOURCES src/runtime.cpp
  INCLUDE_DIR include
  POLICIES runtime)

# Same project, deliberately boring std-only target.
boilerplate_add_executable(tool
  SOURCES tools/tool.cpp
  POLICIES minimal)

# One-off escape hatch without inventing another named profile.
boilerplate_add_test(runtime_test
  SOURCES tests/runtime.cpp
  LIBRARIES my_runtime::my_runtime
  POLICIES minimal tsan
  POLICY_OPTIONS WARNINGS_AS_ERRORS OFF)
```

Predefined orthogonal policies are `minimal` (`cpp-minimal` alias), `hardened` (`hardening` alias), `coverage`,
`debug-symbols`, `frame-pointers`, `werror`, `ccache`, `clang-tidy`, `unity`, `native`,
`thin-lto`, `full-lto`, `lld`, `gc-sections`, `no-plt`, `no-semantic-interposition`,
`icf`, `cfi`, `cfi-icall`, `cfi-vcall`, `windows-cfg`, `asan`, `ubsan`,
`asan-ubsan`, `tsan`, `lsan`, `pgo-generate`, and `pgo-use`.
`minimal` explicitly removes
expensive optimization/instrumentation/tooling defaults (LTO, PGO, sanitizer, CFI, CFG,
native tuning, clang-tidy, ccache, etc.) while keeping the project's selected C++
standard and artifact naming. This is the small denominator for `src/ + include/`
projects.

Policies are just reusable settings; they do not replace direct target-level CMake.
For an existing target the equivalent is:

```cmake
add_library(core STATIC core.cpp)
boilerplate_apply_target_policy(core POLICIES minimal native full-lto)

# Or configure first, then apply later.
boilerplate_configure_target(core POLICIES minimal
  LTO_MODE full ENABLE_NATIVE ON)
boilerplate_apply_target_policy(core)
```

Settings compose as `project defaults -> POLICIES (left-to-right) -> explicit
POLICY_OPTIONS`. `boilerplate_add_library` also accepts `SHARED_POLICIES`,
`STATIC_POLICIES`, `SHARED_POLICY_OPTIONS` and `STATIC_POLICY_OPTIONS`; these are
appended after the common library policy for the corresponding real target. Use
`boilerplate_get_target_setting(target KEY out)` when another module needs the
resolved value, and `boilerplate_print_target_policy(target)` for configure-time
diagnostics.

Policies also support `HOOKS` for domain mechanics that are not compiler flags.
That is the intended extension point for Qt, Vulkan/GLFW/ImGui, shader pipelines,
etc., without teaching the generic library/runtime substrate about them:

```cmake
function(project_qt_widgets target)
  find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
  set_target_properties(${target} PROPERTIES AUTOMOC ON AUTOUIC ON AUTORCC ON)
  target_link_libraries(${target} PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets)
endfunction()

boilerplate_define_policy(qt-widgets
  HOOKS project_qt_widgets)

boilerplate_add_executable(editor
  SOURCES src/editor.cpp
  POLICIES minimal qt-widgets)
```

A hook receives the target name and runs once after the generic target policy was
applied. Domain-specific modules can therefore define `runtime`, `qt-widgets`,
`vulkan-imgui`, or project-local policies as compositions instead of multiplying
presets. Build configuration (`Debug`/`Release`, compiler/toolchain, generator) stays
orthogonal and belongs in presets/toolchain files.


### Control-flow protection

Control-flow protection is target policy, independent of the existing `SANITIZER`
setting. The implementation lives in `ControlFlow.cmake` and is loaded by the
normal `Boilerplate.cmake` entry point; no project-specific flag scripts are needed.

| Policy | Effective settings / behavior |
| --- | --- |
| `cfi` | Clang's `-fsanitize=cfi` schemes, ThinLTO, lld, hidden default visibility |
| `cfi-icall` | Type checks on indirect function calls, ThinLTO, lld |
| `cfi-vcall` | Type checks on virtual calls, ThinLTO, lld, hidden default visibility |
| `windows-cfg` | `/guard:cf` compilation and `/GUARD:CF /DYNAMICBASE` linking |
| `runtime-hardened` | `runtime` + `hardening` + `cfi`; also links Threads |

```cmake
boilerplate_add_executable(game
  SOURCES src/main.cpp
  POLICIES runtime-hardened)

# A narrower check, Full LTO instead of the policy's ThinLTO default,
# and diagnostic output before termination.
boilerplate_add_executable(tool
  SOURCES tools/main.cpp
  POLICIES minimal cfi-icall
  POLICY_OPTIONS LTO_MODE full CFI_DIAGNOSTICS ON)

# Windows is a separate backend; it does not check C++ function signatures.
boilerplate_add_executable(windows_game
  SOURCES src/main.cpp
  POLICIES runtime hardening windows-cfg)
```

Select the example matching the toolchain: this implementation supports CFI on
Linux with GNU-style Clang, and CFG on Windows with MSVC/clang-cl. Other platforms,
CFI without LTO and mixed CFI/CFG fail at configure time. A compile-and-link probe
checks the actual linker and sanitizer-runtime combination. CFG also rejects
the `/ZI` Edit and Continue and `/clr` modes in the project compiler flags.

The project defaults are `BOILERPLATE_CFI=none|cfi|cfi-icall|cfi-vcall`,
`BOILERPLATE_CFI_DIAGNOSTICS=OFF` and `BOILERPLATE_WINDOWS_CFG=OFF`. The matching
target keys are `CFI`, `CFI_DIAGNOSTICS` and `WINDOWS_CFG`. Setting the CFI cache
variable alone requires an explicit `BOILERPLATE_LTO_MODE=thin|full` and an
LTO-capable linker (normally `BOILERPLATE_USE_LLD=ON`). Named CFI policies already
supply these defaults; later policies or `POLICY_OPTIONS` can override them.
CFI traps by default. Diagnostics mode reports the violation and terminates;
it does not recover and continue execution. `minimal` resets all three settings.

Apply CFI to every owned target that contains code you want instrumented, including
static libraries. Static/object targets forward final-link requirements; they do
not instrument their consumers' source files. Shared-library checks cover that
library's own link unit. Diagnostic shared libraries also forward the UBSan runtime
link requirement to their executable consumers. This does **not** enable cross-DSO
CFI: DLL/plugin callbacks, exported polymorphic classes and scripting/JIT boundaries
need a deliberate ABI design. Explicitly exported classes may have public LTO
visibility and therefore no virtual-call CFI checks. See the
[Clang CFI documentation](https://clang.llvm.org/docs/ControlFlowIntegrity.html).
Windows CFG has different guarantees; see
[Microsoft's CFG documentation](https://learn.microsoft.com/en-us/cpp/build/reference/guard-enable-control-flow-guard).

`boilerplate_check_control_flow` is available with Ninja plus Clang/lld on Linux,
or Ninja plus MSVC/clang-cl on Windows. It builds real fixtures, runs valid calls,
checks CFI rejection of mismatched indirect/virtual calls in both trap and
diagnostic modes, and checks Windows EXE/DLL CFG metadata using `dumpbin`.
Linux CI runs CFI checks; Windows CI runs CFG checks.

### Built-in domain policies

The reusable layer now ships three domain modules. Runtime policies are archetypes;
Qt/graphics policies are pure capabilities and therefore do **not** reset whatever
optimization policy was already selected on the target.

```cmake
# Portable runtime baseline; links Threads::Threads.
boilerplate_add_library(core
  SOURCES src/core.cpp INCLUDE_DIR include
  POLICIES runtime)

# CPU-bound scheduler/executor: native + full LTO + lld + section GC + ICF,
# no PLT and no ELF semantic interposition.
boilerplate_add_library(scheduler
  SOURCES src/scheduler.cpp INCLUDE_DIR include
  POLICIES runtime-dagflow)

# Event-loop/server runtime: native + ThinLTO + lld + section GC + ICF + no PLT;
# semantic interposition remains enabled because DSOs/plugins are common.
boilerplate_add_executable(server
  SOURCES src/server.cpp
  POLICIES runtime-webserver)

# Diagnostics deliberately start from the portable runtime baseline.
boilerplate_add_test(race_test SOURCES tests/race.cpp
  LIBRARIES scheduler::scheduler POLICIES runtime-tsan)
```

Runtime policies: `runtime`, `runtime-hardened`, `runtime-dagflow`, `runtime-webserver`,
`runtime-profiled`, `runtime-asan`, `runtime-tsan`,
`runtime-dagflow-profiled`, `runtime-webserver-profiled`. The two tuned runtime
profiles intentionally target Clang/lld-style local performance work; `runtime-webserver`
uses ThinLTO. Use `runtime` plus orthogonal primitives for GCC/MSVC or portable distribution artifacts.

Qt policies: `qt-core`, `qt-gui`, `qt-widgets`, `qt-network`, `qt-qml`,
`qt-quick`, `qt-concurrent`, `qt-sql`, `qt-test`, plus `qt-desktop` and
`qt-qml-app` convenience compositions. They call `find_package(Qt6)`
only when applied. For example:

```cmake
boilerplate_add_executable(editor
  SOURCES src/editor.cpp
  POLICIES minimal qt-widgets qt-network)
```

Graphics policies: `vulkan`, `glfw`, `glew`, `glm`, `imgui`,
`graphics-vulkan`, `graphics-opengl`, `graphics-vulkan-imgui`,
`graphics-opengl-imgui`, and kitchen-sink `graphics` (Vulkan + GLFW + GLEW + GLM + ImGui). `imgui` accepts an existing target through
`BOILERPLATE_IMGUI_TARGET`; otherwise common imported target names are detected.
Shader sources need parameters and are therefore an explicit helper rather than a
policy:

```cmake
boilerplate_add_executable(viewer SOURCES src/viewer.cpp
  POLICIES minimal graphics-vulkan-imgui)
boilerplate_add_glsl_shaders(viewer
  SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shaders"
  COPY_TO_RUNTIME)
```

The useful composition rule is: **archetype first, capabilities after it**. Thus
`POLICIES runtime-dagflow qt-network` keeps the runtime tuning, while a Qt policy
never smuggles `minimal` in and resets earlier settings.

Source-aware mechanics stay explicit rather than becoming fake booleans. Use
`boilerplate_enable_pch(target HEADERS <...> ...)` for PCH,
`boilerplate_add_glsl_shaders()` for shader inputs, and
`boilerplate_enable_qt_deployment(target)` when an installed Qt application should
use Qt's native generated deployment script. `unity` remains an ordinary target
policy because it needs no project-specific input.

## General CMake process harness

`benchmark/Scenarios.cmake` provides lightweight smoke tests, PGO registration and
named workloads. `benchmark/Harness.cmake` adds case matrices, CPU affinity,
randomized rounds, provenance, JSON metrics and optional Linux `perf stat` counters.
Both runners execute through CMake without a Python runtime.

```cmake
boilerplate_add_harness(runtime_matrix
  TARGET runtime_bench
  CASES "${CMAKE_CURRENT_SOURCE_DIR}/bench/cases.json"
  ROUNDS 9 WARMUP_RUNS 2 TIMEOUT 120
  AFFINITY physical RANDOMIZE
  METRICS run_p50_us payload_tasks_per_second
  INVARIANTS checksum)
```

The cases JSON contains project semantics (`scenario`, workers, task counts encoded
as executable arguments); the harness itself knows nothing about DAGs, HTTP, shards,
frames or allocators. Running `run_runtime_matrix` creates a self-contained result
directory with provenance, command records, metric summaries and stdout/stderr logs.
See the [harness guide](cmake/benchmark/README.md).

## Benchmarks and named scenarios

```cmake
boilerplate_add_benchmark(my_bench GROUP custom
  SOURCES bench/custom.cpp LIBRARIES my_math::my_math
  ARGS --tasks 10000)

# An individual/group filter may have disabled the executable.
if(TARGET my_bench)
  boilerplate_add_scenario(small TARGET my_bench GROUP custom
    ARGS --tasks 10000
    SMOKE SMOKE_ARGS --tasks 1
    PGO PGO_ARGS --tasks 100
    ENVIRONMENT "DATA_PATH=${CMAKE_CURRENT_SOURCE_DIR}/data"
    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    REPEATS 7 WARMUP 2 TIMEOUT 30
    LABELS api)
endif()

boilerplate_add_google_benchmark(my_google_bench GROUP google
  SOURCES bench/google.cpp LIBRARIES my_math::my_math
  ARGS --benchmark_filter=MyOperation)
```

Each benchmark gets `run_<target>`, each extra scenario gets `run_<name>`.
Names/groups accept letters, digits, `_`, `-`. Arguments are CMake lists, not shell
strings. Shell expansion is never used. `COMMAND_PREFIX` can supply an explicit
list such as `perf;stat;--`. Tests run the executable directly via CTest; measurements
use `RunWorkload.cmake`. `SMOKE` and `PGO` explicitly opt into those registrations;
`SMOKE_ARGS` / `PGO_ARGS` do not inherit measurement arguments accidentally.
The PGO registration inherits the scenario environment, cwd and timeout.

Google Benchmark uses `benchmark::benchmark_main`; benchmark source files register
operations without supplying another main. Native default flags request five
repetitions and JSON output. Its outer process harness runs once with no extra
warmup. Google registration smoke only lists operations. To check execution manually
without a measurement campaign, use `--benchmark_min_time=1x --benchmark_repetitions=1`.
Per-target arguments are overridable via `BOILERPLATE_<TARGET>_ARGS`.

`boilerplate_register_check(name target ARGS ... LABELS ... TIMEOUT ...
ENVIRONMENT ... WORKING_DIRECTORY ...)` registers an existing executable with CTest.
`boilerplate_tests` builds check binaries; `boilerplate_check` builds them and runs
CTest. GoogleTest uses `boilerplate_add_googletest(name SOURCES ... LIBRARIES ...
LABELS ...)`, optionally `OWN_MAIN`. It discovers cases through native CMake's
GoogleTest module. Call helpers only for enabled components; they do not download
or discover dependencies until needed.

## Training, external projects and upstream comparison

```cmake
boilerplate_pgo_workload(my_test --small)
boilerplate_add_reference(old_version
  SOURCE_DIR "${REFERENCE_SOURCE}"
  CMAKE_ARGS -DCMAKE_BUILD_TYPE=Release
  TEST INSTALL)

boilerplate_add_google_comparison(compare_google
  SCRIPT "${GOOGLE_BENCHMARK_SOURCE}/tools/compare.py"
  BASELINE "${CMAKE_BINARY_DIR}/before.json"
  CANDIDATE "${CMAKE_BINARY_DIR}/after.json")
```

PGO targets exist in generate mode after the first workload is registered. Workloads
run in registration order, with failures/timeouts propagated. LLVM merge uses
`MergeProfiles.cmake`; profile filenames include target/process IDs. Relative training
paths use the caller's binary directory unless a scenario specifies a working directory.

`boilerplate_add_reference` builds an explicit CMake source tree with ExternalProject.
It is excluded from ALL and has its own binary/install directories. `TEST` and
`INSTALL` are optional. Supply compatible compiler/profile arguments yourself.
For non-CMake sources use CMake's ExternalProject directly with explicit commands.
`boilerplate_add_google_comparison` calls the upstream Python tool through CMake;
it does not replace Google's result schema or statistical comparison.

## Allocator and fuzz adapters

```cmake
boilerplate_use_allocator(my_app ALLOCATOR mimalloc PREFIX MY_APP)
# Separate copy: coverage reaches library code without instrumenting production targets.
boilerplate_add_fuzz_library(parser_fuzz_runtime SOURCES src/parser.cpp)
target_include_directories(parser_fuzz_runtime PUBLIC include)
boilerplate_add_fuzzer(parser_fuzz SOURCES fuzz/parser.cpp LIBRARIES parser_fuzz_runtime
  SEED_CORPUS fuzz/seeds MAX_LEN 4096 RUN_SECONDS 60)
```

Allocator choice defaults to `BOILERPLATE_ALLOCATOR`; PREFIX defaults to
`BOILERPLATE`. The application implements allocation/free branches using the
compile definitions. No allocator replacement is automatic.

`boilerplate_add_fuzz_library` creates a private static archive with coverage,
selected fuzz sanitizers, debug information and frame pointers. It is not
installed/exported and does not supply a fuzzer main. Link it only into matching
fuzz drivers. `boilerplate_add_fuzzer` instruments the driver and supplies the
engine. Both accept `BACKEND`, `POLICIES`, `POLICY_OPTIONS`, `SOURCES` and `LIBRARIES`.
The default backend is `BOILERPLATE_FUZZ_BACKEND` (`libfuzzer`, `aflpp`, `honggfuzz`).
AFL++/honggfuzz require their compiler wrappers at configure time. Fuzz archives
and their drivers must agree on backend and `BOILERPLATE_FUZZ_SANITIZER`.

`SEED_CORPUS` copies read-only inputs into a mutable build-tree corpus. `CORPUS`
instead chooses an existing mutable working directory; these options are exclusive.
The helpers register `boilerplate_fuzzers` (build), `fuzz-smoke` (CTest seed replay),
and `fuzz_<target>` (explicit campaign). `BOILERPLATE_FUZZ_RUNTIME` defaults to 60
seconds; `BOILERPLATE_FUZZ_TIMEOUT` bounds each libFuzzer input to 15 seconds.
`BOILERPLATE_FUZZ_SMOKE_LABEL` adds a configurable CTest label.

Run the instrumentation/isolation regression with `boilerplate_check_fuzz` in a
standalone library build, or `cmake -DCHECK_BINARY=/tmp/fuzz-check -P
lib/tests/cmake/verify_fuzz.cmake` from the repository root. It checks that UB in
a linked fuzz archive fails, ordinary libraries stay uninstrumented, seed inputs
are preserved and incompatible settings are rejected.

## File map

The stable entry points are `cmake/Bootstrap.cmake` and `cmake/Boilerplate.cmake`.
Copy the whole `cmake/` tree, including its subdirectories.

| Directory under `cmake/` | Responsibility |
| --- | --- |
| `build/` | Profiles, target policies/options, artifact roles, control-flow checks, build matrix and shared presets |
| `testing/` | Workload target registration, CTest, property tests, fuzzing and coverage |
| `benchmark/` | Harness, scenarios, process execution, result comparison and PGO profile merging |
| `packaging/` | Library variants/exports, config templates, vcpkg ports, CPack and delivery helpers |
| `dependencies/` | Dependency providers, allocators, ExternalProject and vcpkg discovery |
| `platforms/` | Runtime, CUDA, Qt, graphics and shader policies |
| `project/` | Lifecycle, developer tools, formatting, analysis, documentation and metadata |
| `docs/` | Capability, CUDA and delivery guides |

See the [module layout and migration notes](cmake/README.md) for direct script paths.

## Publishing libraries through vcpkg

`boilerplate_vcpkg_port()` generates `vcpkg.json`, `portfile.cmake` and `usage`
under `<build>/vcpkg-ports/<name>` during configuration. It uses the existing
install/export rules and selects exactly one library variant from the vcpkg
triplet. Debug and release CMake exports are fixed up by vcpkg.

Generate and install the example ports from the repository root:

```sh
cmake -S lib -B out/ports -DBOILERPLATE_GENERATE_VCPKG_PORTS=ON
vcpkg install library1 library2 --classic --overlay-ports=out/ports/vcpkg-ports
```

In a manifest consumer, add `library1` / `library2` to `dependencies` and pass
`-DVCPKG_OVERLAY_PORTS=/absolute/path/to/out/ports/vcpkg-ports` alongside the
vcpkg toolchain. Consume with `find_package(library1 CONFIG REQUIRED)` and
`target_link_libraries(app PRIVATE library1::library1)`.

For your own library, include `Boilerplate.cmake` and declare:

```cmake
boilerplate_vcpkg_port(my-math
  VERSION 1.2.0
  DESCRIPTION "My math library"
  SPDX_LICENSE MIT
  LICENSE_FILE LICENSE
  PACKAGES my_math
  SOURCE_DIR "${PROJECT_SOURCE_DIR}")
```

`PACKAGES` lists installed CMake package names, which may differ from the lowercase
vcpkg port name. `SOURCE_DIR` defaults to the current source directory.
`SOURCE_SUBDIR` optionally selects the CMake project inside that source root;
`LICENSE_FILE` is always relative to the source root. The source root must also
contain any shared CMake modules needed by the library.

Optional arguments: `HOMEPAGE`, `DEPENDENCIES fmt zlib` (vcpkg port names),
`OPTIONS -DMY_FEATURE=ON`, and `OUTPUT_DIRECTORY` (the parent of port directories).
Dependencies still need matching CMake linkage and `find_dependency()` calls in
the installed package config; they are not inferred from target names.

For distribution, replace `SOURCE_DIR` with `URL https://…/my-math-1.2.0.tar.gz`
and `SHA512 <128-digit-archive-hash>`. Compute the hash with
`cmake -E sha512sum <archive>`. Archives use vcpkg's default extraction behavior
(one enclosing directory is stripped). Copy the resulting port directory into
an overlay or private registry; registry baselines/version history are managed
separately. Local-source ports contain an absolute checkout path and are intended
for development only: vcpkg does not track changes to that checkout in its binary
cache, so remove/reinstall the port with `--binarysource=clear` after source edits.

See the official [overlay port documentation](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports).
