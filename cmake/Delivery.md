# Shaders, plugins and application delivery

These helpers are included by `Boilerplate.cmake`. Ordinary inclusion does not
search for shader compilers or deployment tools. All workflows use native CMake;
Python is not required.

## Shader compilation

```cmake
boilerplate_add_executable(viewer SOURCES main.cpp)
boilerplate_add_glsl_shaders(viewer
  NAME forward
  SOURCE_DIR shaders
  SOURCES mesh.vert mesh.frag
  INCLUDE_DIRS shaders/include
  DEFINES LIGHT_COUNT=4
  COPY_TO_RUNTIME)
boilerplate_add_glsl_shaders(viewer
  NAME shadow
  SOURCE_DIR shaders
  SOURCES mesh.vert
  INCLUDE_DIRS shaders/include
  DEFINES SHADOW_PASS=1
  COPY_TO_RUNTIME)

boilerplate_add_hlsl_shaders(viewer
  NAME tonemap
  SOURCE_DIR shaders
  SOURCES tonemap.hlsl
  PROFILE ps_6_0 ENTRY_POINT main
  FORMAT DXIL # or SPIRV, with a DXC build supporting SPIR-V
  COPY_TO_RUNTIME)
```

Each call declares a named variant. A name must be unique within a target.
`boilerplate_add_shaders()` is the common API with `LANGUAGE GLSL|HLSL`.
GLSL prefers `glslc`, then `glslangValidator`; HLSL uses `dxc`.
`COMPILER` selects a compiler path/name; `BACKEND glslc|glslang|dxc` is useful for
wrappers or explicitly selecting a GLSL backend. The GLSL wrapper also honors
`Vulkan_GLSLC_EXECUTABLE` when no backend/compiler is explicitly selected.
GLSL can discover supported shader suffixes recursively when `SOURCES` is omitted;
HLSL requires explicit sources sharing the specified profile and entry point.

`DEFINES`, `INCLUDE_DIRS` and `OPTIONS` are lists. `DEPENDS` accepts extra files or
generator targets, such as a target producing an include before the first build.
Compiler-generated depfiles track transitive includes on subsequent builds.
Known absolute source/include prefixes are escaped for directories containing
spaces. Keep transitive include filenames themselves free of whitespace: shader
compiler depfile formats do not consistently preserve those filename boundaries.
DXC needs separate dependency-generation and compilation invocations.
See the [DXC option definitions](https://github.com/microsoft/DirectXShaderCompiler/blob/main/include/dxc/Support/HLSLOptions.td).

Outputs are `<OUTPUT_DIR>/<config>/<variant>/<source-relative-path>.spv|.dxil`;
the default output directory is `<binary-dir>/shaders/<target>`. The unnamed
`default` variant omits its variant subdirectory. Debug and Release have separate
outputs. Files outside `SOURCE_DIR` and duplicate output paths are rejected.
The helper appends outputs to `BOILERPLATE_SHADER_OUTPUTS` on the owner target;
use `TARGET_GENEX_EVAL` when evaluating that property inside generator expressions.

Building the owner or `<target>_shaders` builds all variants. With `COPY_TO_RUNTIME`,
copies under `<executable-dir>/shaders/<variant>` are refreshed even when no C++
file changed; deleted copies are restored on the next build. Register shaders
before calling `boilerplate_install_application()` to install their binaries too.

## Plugins and ABI

```cmake
boilerplate_add_plugin(renderer_plugin
  APPLICATION editor
  SOURCES plugin.cpp
  INCLUDE_DIRS include
  LIBRARIES renderer_core::renderer_core
  POLICIES minimal hardening)
```

This creates a `PLUGIN` artifact, currently materialized as a CMake `MODULE`, with
hidden visibility, PIC and the normal target policy machinery. `APPLICATION editor` registers
ownership in the application graph; it is not a link edge. Include the generated
`renderer_plugin_export.h` and mark the
C entry point with `RENDERER_PLUGIN_EXPORT`. The binary has no `lib` prefix and
uses the platform's module suffix. Windows build-tree DLL dependencies known to
CMake are copied beside the plugin. Load the module at runtime; do not link a
host against a `MODULE` target.

`examples/plugins` provides a host using `LoadLibraryExW`/`dlopen`, symbol lookup,
ABI version/size validation, and a reload cycle. The contract passes fixed-width
values through one C entry point and a function table; it passes no STL objects,
exceptions or allocations across the boundary. The host retains state, finishes
calls, discards all plugin pointers, unloads, then loads the next generation.

```sh
cmake -S . -B out/build/plugins -G Ninja -DBOILERPLATE_BUILD_EXAMPLES=ON
cmake --build out/build/plugins --target plugin_host
ctest --test-dir out/build/plugins -R plugin_reload --output-on-failure
# The host accepts: plugin_host plugin [replacement-plugin] [resource-file]
```

This is an explicit reload example, not a background file watcher or an engine
state-migration system. A threaded host must stop calls and join plugin workers
before unloading; plugin-owned objects must be destroyed while its code is loaded.
Pass a different file path to load a replacement binary. Platform/architecture and
calling conventions still must match even with a C ABI.

CFI applies within its link unit. `cfi-icall` on a host calling arbitrary plugin
function pointers is not automatically compatible with a dynamically loaded module.
The example uses `minimal`; choose an explicit boundary strategy before applying
CFI to a real plugin host. The plugin helper rejects diagnostic CFI because its
UBSan runtime would need explicit integration with the host; trap-mode internal
CFI and Windows CFG remain available.

## Hosted application model

The framework treats application identity, process hosting and link-time libraries as
different concepts. A complete application can be declared in one call:

```cmake
boilerplate_add_runtime(engine
  SOURCES engine.cpp
  INCLUDE_DIRS include
  POLICIES runtime)

boilerplate_add_application(editor
  SOURCES editor.cpp
  RUNTIMES engine
  RESOURCE_DIRS assets
  POLICIES runtime)

boilerplate_add_plugin(renderer_vulkan
  APPLICATION editor
  SOURCES renderer_vulkan.cpp
  POLICIES runtime)

# Same Editor application image, second process realization.
boilerplate_add_host(editor_cli KIND CONSOLE POLICIES minimal)
boilerplate_host_application(editor_cli editor)

boilerplate_install_application(editor)
```

`boilerplate_add_application(editor ...)` creates an `APPLICATION` module target named
`editor` plus a generated `HOST` target named `editor_host`; the host output file is
`editor`. Application source provides:

```cpp
int boilerplate_application_main(int argc, char** argv) {
  // application logic
  return 0;
}
```

The framework generates the C-shaped bootstrap export and the host performs explicit
`LoadLibraryExW`/`dlopen` loading. Use `boilerplate_add_application_module(...
ENTRYPOINT CUSTOM)` when the project needs a different bootstrap contract or a custom
host implementation. `boilerplate_add_host(... SOURCES ...)` plus a typed hosting edge keeps the same graph
semantics while letting the project own process bootstrap.

One application may have multiple hosts. Host-specific process policy (GUI/console,
service integration, crash handling, test harnessing, etc.) belongs to the host; domain
state and application behavior belong to the application image. Runtime modules are
private, linkable process components. Plugins are runtime-loaded extension images.
Ordinary libraries remain link-time consumer artifacts.

Plugin membership and execution placement are independent edges:

```cmake
boilerplate_add_plugin(git_extension
  APPLICATION editor
  SOURCES git_extension.cpp)

# No HOST -> PLUGIN edge: git_extension follows editor's hosts and is therefore
# an in-process/co-hosted extension by topology. The editor/runtime owns its ABI
# and loading policy.

boilerplate_add_plugin(untrusted_extension
  APPLICATION editor
  SOURCES untrusted_extension.cpp)

boilerplate_add_host(extension_sandbox
  SOURCES extension_sandbox.cpp)
boilerplate_host_plugin(extension_sandbox untrusted_extension)
```

`APPLICATION -> PLUGIN` means "this is an extension of the application". With no
explicit plugin host, its effective hosts are the application's hosts. As soon as
one or more explicit `HOST -> PLUGIN` edges exist, those hosts define the plugin's
execution placement instead. This permits in-process, dedicated-process and
multi-host layouts without changing the plugin artifact itself. The framework does
not prescribe a universal plugin business ABI; application/runtime code or a custom
plugin host owns the actual `dlopen`/`LoadLibrary` contract and symbol negotiation.
`boilerplate_install_application()` follows both kinds of edge, so dedicated plugin
hosts are installed automatically as part of the application product.

`HOST` is not application-specific. A plugin loader is the same execution artifact
with a different typed edge:

```cmake
boilerplate_add_plugin(renderer_plugin SOURCES renderer.cpp)
boilerplate_add_host(renderer_host SOURCES renderer_host.cpp)
boilerplate_host_plugin(renderer_host renderer_plugin)
boilerplate_install_host(renderer_host)
```

Because plugin ABIs are project/domain contracts rather than a framework-wide ABI, a
plugin-only host supplies `SOURCES`. `boilerplate_install_host()` follows registered
`HOST -> PLUGIN` edges and their private shared/runtime dependencies, so deployment
does not repeat the composition graph.

## Installed application layout

The semantic application target, not an executable, is the deployment root:

| Artifact | Destination under the installation prefix |
| --- | --- |
| Registered hosts | `bin/` |
| Application image | `lib/<application>/` |
| Private runtime modules / owned shared libraries | `lib/<application>/` |
| Plugins | `lib/<application>/plugins/` |
| Contents of resource directories | `share/<application>/` |
| Compiled shader variants | `share/<application>/shaders/` |

This is intentionally application-private. A runtime module being a `.dll`/`.so` does
not make it a system-wide reusable library. Consumer-facing libraries should be built
with `boilerplate_add_library()` and use its normal package/export installation model.

`boilerplate_install_application(app)` automatically reads hosts, runtimes, plugins,
owned shared link dependencies and resources already registered on `app`. The optional
`HOSTS`, `RUNTIMES`, `LIBRARIES`, `PLUGINS` and `RESOURCE_DIRS` arguments extend that
graph for explicit/foreign targets. Runtime-to-runtime edges declared through
`boilerplate_add_runtime(... LIBRARIES ...)` are followed for deployment.

On Linux/macOS the backend writes relative loader paths for the semantic topology:
the application and runtimes resolve private peers from their own directory; plugins
resolve their own directory and the parent application directory; hosts resolve the
application-private directory. On Windows the generated host adds the private module
directory to the DLL search scope before loading the application image.

External dependencies of registered binaries can be collected with CMake's native
runtime dependency scanner. OS libraries are excluded by default;
`PRE_EXCLUDE_REGEXES` and `POST_EXCLUDE_REGEXES` extend the filters, and `RUNTIME_DIRS`
provides additional search directories. On Linux this scan/fixup path requires
`patchelf`. `NO_RUNTIME_DEPENDENCIES` disables external scanning while preserving the
explicit semantic graph, resources and relocatable paths; cross compilation requires
that mode plus target-specific packaging.

The former executable-root API remains as a compatibility escape hatch:

```cmake
boilerplate_add_executable(legacy_app SOURCES main.cpp)
boilerplate_install_application(legacy_app
  LIBRARIES owned_shared
  PLUGINS old_plugin
  RESOURCE_DIRS assets)
```

New code should prefer an `APPLICATION` root because that model preserves application
identity independently of any one host and naturally supports multi-host products.
`BOILERPLATE_INSTALL=OFF` disables installation. Build before installing;
`cmake --install` does not build targets.

The semantic helper exposes `BOILERPLATE_INSTALL_PRIVATE_DIR`,
`BOILERPLATE_INSTALL_PLUGIN_DIR` and `BOILERPLATE_INSTALL_RESOURCE_DIR` on the
application target for generated configuration.

## Regression checks

```sh
cmake --build out/build/plugins --target boilerplate_check_execution_model
cmake --build out/build/plugins --target boilerplate_check_delivery
cmake --build out/build/plugins --target boilerplate_check_shaders
```

The application-model and delivery checks exercise Ninja and Ninja Multi-Config.
The application-model check builds one application image with a private runtime, plugin
and two generated hosts, then moves the install tree and launches both hosts. Delivery
checks the compatibility executable-root path, ABI mismatch,
missing entry point, reload, owned and transitive external libraries, resources,
and launching a relocated installation after deleting the original build trees.
Shader checks use real available compilers in paths containing spaces and exercise named variants, nested
include edits, no-op builds, runtime copy recovery, install and configuration
separation. A missing backend is reported as skipped; no available backend fails.
For strict checks, run `verify_shaders.cmake` with `REQUIRE_ALL_BACKENDS=ON`.
Linux CI installs all three compilers; Windows/macOS CI runs native delivery checks.
