# Repository files must match an explicit include or exclude rule. Unknown files
# fail the manifest check, so new top-level areas require a deliberate decision.
set(TEMPLATE_INCLUDE_PATTERNS
  "^\\.(clang-format|clang-format-ignore|clang-tidy|cmake-format\\.yaml|dockerignore|gitignore)$"
  "^\\.github/workflows/[^/]+\\.ya?ml$"
  "^(CMakeLists\\.txt|CMakePresets\\.json|Dockerfile|LICENSE|README\\.md|Structure\\.md|docker-compose\\.yaml|vcpkg(-configuration)?\\.json)$"
  "^(setup|setup-host|build|build_all|format_cmake|format_parallel)\\.(sh|ps1)$"
  "^(devenv_and_run|docker_devenv)\\.sh$"
  "^(cmake|lib|src|include|tests|examples|scripts|tools|toolchains|shaders)/"
  "^vcpkg/(README\\.md|ports/|triplets/)")
set(TEMPLATE_EXCLUDE_PATTERNS
  # Published registry identity/history belongs to this repository, not to a
  # newly generated application. Generated projects retain development overlays.
  "^(ports|versions|tests/registry-consumer)/"
  "^vcpkg/release\\.json$"
  "^scripts/registry\\.py$"
  "^\\.github/workflows/vcpkg-registry\\.yml$"
  "^\\.gitattributes$"
  "^cmake_boilerplate_capabilities_graph\\.(dot|svg|png)$"
  "^(docs|out|build|artifacts|external|third_party|vcpkg_installed)/"
  "(^|/)(CMakeFiles|_deps|__pycache__|\\.git|\\.cache|\\.venv)/"
  "(^|/)(CMakeCache\\.txt|CMakeUserPresets\\.json|compile_commands\\.json|build\\.ninja|cmake_install\\.cmake|install_manifest[^/]*\\.txt)$"
  "(^|/)\\.env($|\\.)")
