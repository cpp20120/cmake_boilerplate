# Repository Guidelines

## Scope & Project Structure

This is an independent CMake application/library framework repository. Run commands here, or explicitly inside `lib/` for standalone core builds.

`lib/cmake/` owns reusable library, target-policy, testing, packaging, and optional Rust infrastructure. Root `cmake/` adds application, host, plugin, and deployment semantics. Sample application code lives in `src/` and `include/`; library examples live in `lib/`. Regression fixtures live in `tests/cmake/` and `lib/tests/cmake/`; shaders and executable examples live in `shaders/` and `examples/`.

## Build, Test, and Development Commands

Use CMake 3.26+, Ninja for supplied presets, and a compiler supporting the selected C++ standard (C++23 by default):

```sh
cmake --workflow --preset app-debug
# Standalone library workflow, from this directory:
cmake --preset lib-release
cmake --build --preset lib-release --parallel 2
ctest --preset lib-release --output-on-failure --no-tests=error
cmake --build --preset lib-release --target boilerplate_check_cmake
```

Root and `lib/` builds have separate output trees; keep configure/build/test commands in the same source directory. `./build.sh --run` rebuilds, tests, and launches the sample; `./setup.sh --run` additionally prepares missing tools. PowerShell equivalents are available.

## Coding Style & Architecture

Use each checked-in formatter configuration: two-space indentation and 80-column C++ formatting; CMake formatting uses two spaces and 120 columns. Use `clang-format`, `cmake-format`, and the configured `clang-tidy` checks as relevant.

Preserve `boilerplate_*` function names and `BOILERPLATE_*` options. Keep bootstrap before `project()`, project capabilities separate from target policies, and application hosting above the standalone core. Apply policies to owned targets; preserve imported dependency settings. Rust tool discovery remains opt-in through the `rust` capability.

## Testing & Template Maintenance

CTest runs dependency-free correctness checks; CMake fixtures use `verify_*.cmake`. Add regressions for behavior changes. For bootstrap/template changes, run:

```sh
cmake -P scripts/TemplateManifest.cmake
bash scripts/test-entry.sh
```

New tracked files need explicit classification in `scripts/TemplatePolicy.cmake`. Follow `scripts/README.md` when updating the template manifest or testing generated projects.

## Commit & Pull Request Guidelines

Use concise imperative commit subjects. Follow `CONTRIBUTING.md`: open an issue for significant API/bootstrap/template changes, and explain affected platforms, compatibility, linked issues, and validation in PRs. Preserve unrelated changes and exclude generated artifacts.

## Project Skill

Use [the boilerplate skill](.agents/skills/cmake-boilerplate/SKILL.md) for framework, packaging, template, or Cargo integration work.
