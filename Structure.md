# Repository structure

```text
.
├── CMakeLists.txt                 # thin application/project composition root
├── CMakePresets.json              # toolchain/configuration selections
├── Dockerfile                     # external dev/build/test/runtime workflow
├── .dockerignore
├── tools/container.py             # tiny Docker CLI wrapper; no CMake coupling
├── lib/
│   ├── CMakeLists.txt             # standalone reusable-library entry point
│   ├── CMakePresets.json
│   ├── README.md                  # reusable API reference
│   ├── cmake/                     # copy this subtree into another project
│   │   ├── Bootstrap.cmake        # pre-project toolchain/provider + in-source guard
│   │   ├── Boilerplate.cmake
│   │   ├── ProjectCapabilities.cmake # project lifecycle composition engine
│   │   ├── project/               # docs/analysis/tests/package/cache/build-info/etc.
│   │   │   └── Documentation.cmake # native CMake/Doxygen integration; no Python wrapper
│   │   ├── TargetPolicies.cmake   # target compile/link composition engine
│   │   ├── RuntimePolicies.cmake  # runtime / DagFlow-like / webserver-like
│   │   ├── QtPolicies.cmake       # Qt6 capabilities + deploy helper
│   │   ├── GraphicsPolicies.cmake # Vulkan/GLFW/GLEW/GLM/ImGui policies
│   │   ├── Shaders.cmake          # GLSL/HLSL variants and compiler depfiles
│   │   ├── Plugins.cmake          # MODULE targets and export headers
│   │   ├── Deployment.cmake       # runtime dependencies, resources and shaders
│   │   ├── Harness.cmake          # optional Python research-harness bridge
│   │   ├── harness/               # dependency-free Python execution core
│   │   └── ...                    # libraries, workloads, PGO, scenarios, packages
│   ├── library1/                  # dependency-free + local/variant policies
│   ├── library2/                  # Threads package dependency + PCH + own policies
│   ├── bench/                     # example benchmarks
│   └── tests/                     # smoke + infrastructure regression fixtures
├── src/                           # example application
├── tests/                         # application tests/fuzzing
├── shaders/                       # example assets; shader helper lives in lib/cmake
├── examples/                      # example workloads and plugins/ ABI/reload host
└── .github/workflows/
```

The reusable boundary is `lib/cmake/`: bootstrap, whole-project capabilities,
target policies and experiment workflows ship together. Ordinary inclusion has
no Python, Qt, Vulkan, Doxygen, GoogleTest or Google Benchmark dependency;
optional tools/packages are discovered only when the corresponding capability,
policy or helper is used.
