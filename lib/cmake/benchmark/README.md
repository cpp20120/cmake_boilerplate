# General process harness

`HarnessCMake.cmake` is the self-contained process harness for native targets. CMake owns the build graph, repeated process execution, CPU placement, provenance, JSON result parsing, fixed-point metric statistics and optional Linux `perf stat` invocation.

The harness has no Python runtime dependency. `boilerplate_add_harness()` generates a per-target config and executes `HarnessCMake.cmake` through `cmake -P`.

A cases file can be a JSON array for the compact form, or an object with shared `defaults`, named `groups`, and `cases`. Each case may define `name`, `args`, `env`, `cwd`, `cpu_count`, an exact `cpus` list, and free-form `metadata`. Object values in `env` and `metadata` are merged with defaults; case values win:

```json
{
  "defaults": {
    "args": ["--scenario", "chain"],
    "env": {"ALLOCATOR": "system"},
    "metadata": {"suite": "scaling"}
  },
  "groups": {
    "smoke": ["chain-1"],
    "full": ["chain-1", "chain-4"]
  },
  "cases": [
    {"name":"chain-1", "args":["--workers","1"], "cpu_count":1},
    {"name":"chain-4", "args":["--workers","4"], "cpu_count":4}
  ]
}
```

The executable can emit one JSON object line per invocation. With the default `json-line` parser, a `status` field is checked when present (`"ok"` is required). `METRICS` selects numeric fields to summarize and `INVARIANTS` selects fields that must remain identical across measured runs.

```cmake
boilerplate_add_harness(runtime_matrix
  TARGET runtime_bench
  CASES "${CMAKE_CURRENT_SOURCE_DIR}/bench/cases.json"
  ROUNDS 7 WARMUP_RUNS 2 TIMEOUT 120
  AFFINITY physical RANDOMIZE
  METRICS run_p50_us payload_tasks_per_second
  INVARIANTS checksum)
```

Add `CASE_GROUP smoke` to that declaration to run only the named subset. The
same file can then serve quick checks and full scaling runs without multiplying
CMake targets or presets.

Build normally, then run explicitly:

```sh
cmake --build out --target run_runtime_matrix
```

The output directory contains `manifest.json`, `runs.jsonl`, `summary.json`, and per-process stdout/stderr logs. Metric summaries use fixed-point micro-units (`scale: 1000000`) so CMake can aggregate decimal values without a floating-point runtime. Linux counters can be requested with `PERF_EVENTS`; raw `perf stat` CSV is retained beside each run log.

## Rust executables and backend provenance (stage 2A)

Both `boilerplate_add_harness()` and `boilerplate_add_scenario()` accept Cargo
executable imports from the opt-in [Rust backend](../rust/README.md). Their public
signatures are unchanged:

```cmake
boilerplate_project(CAPABILITIES rust testing)
boilerplate_add_rust_executable(rust_bench
  MANIFEST rust/Cargo.toml KIND bin CARGO_TARGET my-benchmark)
boilerplate_add_harness(rust_matrix TARGET rust_bench
  ARGS --items 100 ROUNDS 5 WARMUP_RUNS 1
  METRICS items INVARIANTS checksum)
boilerplate_add_scenario(rust_small TARGET rust_bench GROUP rust
  ARGS --items 100 REPEATS 3 WARMUP 1
  SMOKE SMOKE_ARGS --items 2)
boilerplate_add_scenario(rust_large TARGET rust_bench GROUP rust
  ARGS --items 1000 REPEATS 3 WARMUP 1)
boilerplate_finalize_project()
```

`run_rust_matrix`, `run_rust_small`, and `run_group_rust` all build their Cargo
dependencies before execution. Artifact resolution remains `$<TARGET_FILE:...>`.
Scenario smoke tests join the existing CTest/check aggregates. Scenario execution
measures process time and captures stdout; it does not parse application metrics.
Use the harness for JSON/JSONL metrics and invariant checks. Invariants mean
consistency across measured rounds, not comparison against an expected value;
applications should signal incorrect answers with a nonzero exit or non-`ok`
JSON status. `PGO` on a Rust scenario is explicitly rejected: remove that option
until Rust PGO is implemented.

The execution scripts, JSON/JSONL/none parsers, cases, warmup/rounds, affinity,
perf, binary hashing, manifests and result layouts are unchanged. Provenance goes
in harness `manifest.json.metadata` or scenario `result.json.build_knobs`.
The existing top-level `compiler` field describes the selected backend; Rust
scenario `profile` is `dev` or `release`, rather than a C++ project profile.

### Internal adapter and target properties

`TargetMetadata.cmake` provides the internal configure-time helper
`boilerplate_collect_target_metadata(target output [FORMAT harness|scenario])`.
It returns the existing CMake list of `key=value` records and the companion
`<output>_COMPILER`, `<output>_PROFILE`, and `<output>_BACKEND` values. `FORMAT`
only preserves the two legacy report layouts; it does not select build settings.
Values containing configuration expressions are resolved by the caller's
existing `file(GENERATE)`. The adapter launches no tools and never queries the
C++ policy API for Rust targets.

New target properties:

| Property | Value/source |
| --- | --- |
| `BOILERPLATE_BUILD_BACKEND` | `rust` on Cargo imports; absent means historical `cxx` behavior; explicit `cxx` is also accepted |
| `BOILERPLATE_RUST_EDITION` | Selected Cargo target's edition from the existing metadata query |
| `BOILERPLATE_RUST_PROFILE` | Configuration expression selecting Cargo `dev`/`release`, shared with the build command |
| `BOILERPLATE_RUST_TARGET_TRIPLE` | Explicit `--target` value used by Stage 1 (the selected host triple) |
| `BOILERPLATE_RUST_BUILD_ID` | Existing artifact-directory identity hash |

All other Rust values reuse the existing `BOILERPLATE_RUST_*` properties.
Sysroot plus absolute compiler/Cargo paths identify the configured installation;
the adapter does not guess a rustup channel name. Reconfigure after changing or
updating a toolchain: this is configure-time provenance, not a fresh probe when
each benchmark runs.

C++ records keep their previous keys, compiler formatting, policy values and
allocator information; only `backend=cxx` is added. Policy values still come
from `boilerplate_get_target_setting()`. Rust gets no C++ policy, allocator,
`CXX_STANDARD`, CFI, Clang or unity-build fields. Do not override backend/compiler
provenance keys with the harness's optional custom `METADATA` entries.

Illustrative harness metadata excerpts (tool versions depend on the machine):

```json
{
  "backend": "cxx",
  "compiler": "Clang-22.1.8",
  "policies": "minimal",
  "CXX_STANDARD": "23",
  "LTO_MODE": "none"
}
```

```json
{
  "backend": "rust",
  "compiler": "rustc-1.98.1",
  "rustc": "/usr/bin/rustc",
  "rustc_version": "1.98.1",
  "rust_host": "x86_64-unknown-linux-gnu",
  "rust_sysroot": "/usr",
  "cargo": "/usr/bin/cargo",
  "cargo_version": "1.98.1",
  "cargo_manifest": "/work/fixture/Cargo.toml",
  "cargo_package": "rust-fixture",
  "cargo_target_kind": "bin",
  "cargo_target_name": "fixture-benchmark",
  "rust_edition": "2021",
  "cargo_profile": "dev",
  "rust_target": "x86_64-unknown-linux-gnu",
  "cargo_features_requested": "[\"answer\",\"benchmark\"]",
  "cargo_no_default_features": "TRUE",
  "rustflags_explicit": "[\"--cfg\",\"cmake_fixture=\\\"value with spaces\\\"\"]",
  "configuration": "Debug"
}
```

The full Rust record also includes target/project/generator, Cargo build target,
build ID and target directory. All metadata values remain strings to preserve the
existing serialization. List-valued features and flags are JSON-array **strings**
so argument boundaries and quotes survive; consumers may parse those strings a
second time. Features are the requested feature list plus the explicit default
feature switch, not a fabricated resolved dependency feature closure. Implicit
features, profile overrides, linker settings and effective compiler options not
known from Stage 1 are omitted. In particular no Rust LTO/sanitizer setting is
inferred from C++ options.

### Dependency-free regression fixture

From the repository root:

```sh
cmake -S lib/tests/cmake/rust -B out/rust-bench -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build out/rust-bench --target run_rust_harness run_rust_first run_group_rust_benchmarks check
ctest --test-dir out/rust-bench -R rust_first_smoke --output-on-failure

cmake -DCHECK_BINARY=/tmp/rust-benchmark-check -P lib/tests/cmake/verify_rust_benchmarks.cmake
cmake -DCHECK_BINARY=/tmp/rust-benchmark-multi-check \
  '-DCHECK_GENERATOR=Ninja Multi-Config' -P lib/tests/cmake/verify_rust_benchmarks.cmake
```

The explicit `boilerplate_check_rust_benchmarks` target in the standalone library
build runs these two generator checks. It is not a dependency of C++ regressions.
The script also accepts Stage 1's `CHECK_RUST_TOOLCHAIN`, `CHECK_RUST_CARGO`, and
`CHECK_RUST_RUSTC` selectors. The fixture emits deterministic item counts and
checksums, tests a generated Rust include dependency, and supplies invalid JSON,
an intentionally changing invariant and an explicit process failure. It exercises
the existing execution gate with a simulated cross context and emulator prefix;
this does not enable Rust cross compilation. Real cross compilation, perf counter
permissions and additional OS/generator combinations need their own host checks.

Extended Rust profiles, fuzzing, sanitizers, coverage, Rust PGO, packaging and
DagFlow-Rust migration remain deferred. Stage 2A adds provenance and reuses the
existing benchmark runners; it does not start Stage 2B.

## What belongs here vs. in a project adapter

The generic harness owns process lifecycle, timeout propagation, affinity, provenance, raw logs, JSON parsing, fixed-point statistics and perf invocation. Project adapters should keep scenario semantics, matrix generation, expected checksums, allocator/runtime-specific build definitions, comparison rules and domain reports. That keeps a DagFlow benchmark, an HTTP server benchmark and a Qt/graphics smoke workload on the same runner without teaching the runner what a shard, request, graph or frame is.
