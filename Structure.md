# Repository structure

```text
.
├── CMakeLists.txt                 # full product/workspace composition root
├── cmake/                         # execution/application layer; depends on lib/cmake
│   ├── Bootstrap.cmake            # facade over the standalone core bootstrap
│   ├── Boilerplate.cmake          # full facade: core + semantic execution layer
│   ├── SemanticTargets.cmake      # shared semantic-artifact mechanics
│   ├── Runtime.cmake              # private runtime images
│   ├── Application.cmake          # hosted application images + happy-path sugar
│   ├── Hosting.cmake              # HOST artifact + typed hosting edges
│   ├── Plugins.cmake              # runtime-loaded extensions
│   ├── Deployment.cmake           # application/host private deployment closure
│   ├── Delivery.md
│   └── host/                      # native generic app-host payload + bootstrap ABI
├── lib/
│   ├── CMakeLists.txt             # standalone reusable-library entry point
│   ├── CMakePresets.json
│   ├── README.md                  # library/core API reference
│   ├── cmake/                     # independently reusable core; no host/app includes
│   │   ├── Bootstrap.cmake
│   │   ├── Boilerplate.cmake
│   │   ├── build/                # profiles, target policies, artifact roles, matrix
│   │   ├── testing/              # CTest, fuzzing, coverage, workload declarations
│   │   ├── benchmark/            # process harness, scenarios, comparison, PGO runner
│   │   ├── packaging/            # library exports, runtime delivery, CPack, vcpkg ports
│   │   ├── dependencies/         # providers and vcpkg discovery
│   │   ├── platforms/            # runtime, CUDA, Qt, graphics/shader policies
│   │   ├── project/              # lifecycle, developer tools, generated metadata
│   │   └── docs/                 # capability, CUDA and delivery guides
│   ├── library1/
│   ├── library2/
│   ├── bench/
│   └── tests/                     # only library/core regressions
├── src/                           # replaceable sample standalone executable
├── tests/
│   └── cmake/                     # full execution/application regression fixtures
├── examples/                      # allocator, Qt and generic plugin-host examples
└── tools/
```

The dependency direction is one-way: the root `cmake/` execution layer consumes
`lib/cmake/`, never the reverse. `lib/` can therefore be copied or configured as a
standalone library workspace. The full framework keeps the same core policies and
project capabilities, then adds hosted applications, runtimes, plugins, process
hosts and deployment topology only when that facade is included.

The execution graph keeps composition separate from placement. `APPLICATION ->
PLUGIN` is an extension-set edge; `HOST -> APPLICATION` and `HOST -> PLUGIN` are
execution-placement edges. Plugins without an explicit host inherit the application's
hosts (co-hosted/in-process by topology). Explicit plugin hosts override that default
placement and are pulled into the application's deployment closure automatically.
