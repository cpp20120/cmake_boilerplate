---
name: cmake-boilerplate
description: Develop and validate the cmake_boilerplate repository's reusable CMake framework, project initializer, application and library layers, packaging, host setup, or optional Rust/Cargo integration. Use for this framework and its generated projects; DagFlow runtime changes belong to the separate DagFlow skill.
---

# CMake Boilerplate Development

## Locate the owning layer

Find the root containing `cmake/Boilerplate.cmake`, `lib/cmake/Boilerplate.cmake`, and `scripts/TemplatePolicy.cmake`. Read `AGENTS.md` and inspect existing changes. Paths below are relative to that root; the skill is stored three directories below it. In generated projects, use the generated identity and existing presets rather than assuming the original application name.

Route work to the smallest owning layer:

| Work | Location and reference |
| --- | --- |
| Library artifacts, policies, capabilities, consumers | `lib/cmake/`; `lib/README.md` |
| Application, host, plugins, deployment | root `cmake/`; `cmake/Delivery.md` |
| Cargo integration | `lib/cmake/rust/`; its `README.md` |
| Initializer and file selection | `scripts/Init.cmake`, `scripts/TemplatePolicy.cmake`; `scripts/README.md` |
| Setup and entry scripts | `setup*.sh`, `build.sh`, PowerShell counterparts, `scripts/entry-options.*` |
| Cross compilation | `toolchains/README.md`, toolchain files and presets |

## Maintain architectural boundaries

- Bootstrap toolchain/dependency choices before `project()`. Configure project capabilities before target registration and finalize after registration.
- Keep project-wide tooling/lifecycle capabilities separate from per-target compilation/link policies and execution workloads. Prefer existing composition APIs over directory-global flags or new preset combinations for every feature.
- The `lib/` slice must remain independently configurable, installable, and consumable without the root application's hosting/deployment machinery. Root and standalone builds use distinct output trees.
- Apply policies to owned targets, leaving imported/third-party target settings intact. Preserve static/shared export names, public dependency propagation, and relocatable package configs.
- Keep optional integrations optional. Including the facade must not require Rust, GPU, GUI, or testing dependencies that the project did not select.
- DagFlow maintains a separate adapted copy of infrastructure. Change this repository's implementation without automatically synchronizing the sibling project.

## Validate the affected workflow

Run from the repository root unless using an explicitly standalone fixture:

```sh
# Configure, build, and test the application layer:
cmake --workflow --preset app-debug

# Configure, build, test, and check library consumers:
cmake --preset lib-release
cmake --build --preset lib-release --parallel 2
ctest --preset lib-release --output-on-failure --no-tests=error
cmake --build --preset lib-release --target boilerplate_check_cmake
```

Use the workflow relevant to the changed layer. Add behavior regressions beside existing `tests/cmake/verify_*.cmake` or `lib/tests/cmake/verify_*.cmake` fixtures. Read the corresponding script or `lib/cmake/docs/CapabilityChecks.md` before selecting optional check targets and prerequisite tools. Validate single- and multi-configuration generators when output paths or configuration handling change.

For bootstrap/entry changes, exercise `scripts/test-entry.sh` and the corresponding PowerShell checks where available. Preserve Bash 3.2 and Windows PowerShell 5.1 compatibility in shared entry points.

## Template changes

The initializer copies an explicit manifest, not the entire checkout. Classify new tracked files in `scripts/TemplatePolicy.cmake`. Source payload belongs in the manifest; repository-specific contributor/agent instructions are excluded from generated projects.

`scripts/TemplateManifest.cmake` reads Git's index, so an unstaged new source file cannot enter its expected manifest. When staging is part of the requested workflow, stage intended source files before updating; otherwise report this prerequisite instead of staging unrelated work.

```sh
cmake -DACTION=update -P scripts/TemplateManifest.cmake
cmake -P scripts/TemplateManifest.cmake
```

For generation behavior changes, follow `scripts/README.md` and run `scripts/test-init.cmake` with a fresh `CHECK_BINARY` directory. Preserve rejection of nonempty destinations and restricted identity substitutions.

## Cargo changes

Read the relevant section of `lib/cmake/rust/README.md`. CMake owns the graph; Cargo owns crate dependencies, fingerprints, and incremental compilation. Discovery requires the explicit `rust` capability, including when `full` is selected.

Keep build/test toolchain, package, features, environment fingerprint, profile, and artifact directories consistent. Build imported executables through their `<target>_cargo` target or a consumer. Select the matching `verify_rust*.cmake` fixture for profile, sanitizer, fuzzing, or environment changes; do not require nightly for ordinary C++ or Rust builds.

Follow `CONTRIBUTING.md` for significant public changes. Report affected layers/platforms, compatibility impact, and checks actually performed.
