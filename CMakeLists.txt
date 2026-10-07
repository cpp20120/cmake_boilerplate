cmake_minimum_required(VERSION 3.26)

# Toolchain/dependency-provider choices that must exist before project().
include(cmake/Bootstrap.cmake)
boilerplate_bootstrap()

project(TEST_PROJECT VERSION 1.0.0 DESCRIPTION "C++ application and library template" LANGUAGES CXX)
if(PROJECT_IS_TOP_LEVEL)
  include(CTest) # enable_testing() must live in the top-level directory scope
endif()

option(BOILERPLATE_LIBRARIES_ONLY "Configure only the library examples" OFF)
option(BOILERPLATE_BUILD_APPLICATION "Build the sample application" ON)
option(BOILERPLATE_BUILD_QT_EXAMPLE "Build the Qt 6 Widgets example" OFF)
option(BOILERPLATE_BUILD_TESTS "Build dependency-free correctness tests" ON)
option(BUILD_DOCS "Enable the reusable Doxygen project capability" OFF)
option(ENABLE_PACKAGING "Enable the reusable CPack project capability" OFF)

# Preserve explicitly selected legacy sanitizer/LTO/fuzzer knobs as project
# defaults, but do not resurrect directory-global compiler/linker flags.
if(ENABLE_SANITIZERS)
  if(NOT SANITIZER)
    set(SANITIZER address)
  endif()
  set(BOILERPLATE_SANITIZER "${SANITIZER}" CACHE STRING "Sanitizer")
endif()
if(ENABLE_LTO)
  set(BOILERPLATE_LTO_MODE full CACHE STRING "LTO mode")
endif()
if(ENABLE_FUZZING)
  set(BOILERPLATE_BUILD_FUZZERS ON CACHE BOOL "Build fuzzers")
endif()

include(cmake/Boilerplate.cmake)

# Project capabilities are lifecycle/tooling concerns. Target compile/link
# semantics remain in POLICIES. Lists are intentionally composable rather than a
# fixed project-profile enum.
set(BOILERPLATE_PROJECT_CAPABILITIES "developer" CACHE STRING
  "Top-level project capabilities (CMake list)")
set(BOILERPLATE_EMBEDDED_PROJECT_CAPABILITIES "project-minimal" CACHE STRING
  "Capabilities when this project is embedded by add_subdirectory")
set(_project_caps ${BOILERPLATE_PROJECT_CAPABILITIES})
if(BUILD_DOCS)
  list(APPEND _project_caps docs)
endif()
if(ENABLE_PACKAGING)
  list(APPEND _project_caps packaging)
endif()
if(BOILERPLATE_COVERAGE)
  list(APPEND _project_caps coverage-report)
endif()
if(BOILERPLATE_BUILD_PROPERTY_TESTS)
  list(APPEND _project_caps property-testing)
endif()
if(BOILERPLATE_BUILD_FUZZERS OR BOILERPLATE_BUILD_FUZZTESTS)
  list(APPEND _project_caps fuzzing)
endif()
list(REMOVE_DUPLICATES _project_caps)

boilerplate_project(
  TOP_LEVEL_CAPABILITIES ${_project_caps}
  EMBEDDED_CAPABILITIES ${BOILERPLATE_EMBEDDED_PROJECT_CAPABILITIES})

boilerplate_project_has_capability(testing _project_testing)
boilerplate_add_component(libraries SOURCE_DIR lib FOLDER "components/libraries")

# Execution/application regressions intentionally live above the standalone
# library slice. They validate the full semantic graph without making lib/
# depend on hosting or deployment machinery.
find_program(_boilerplate_ninja ninja)
if(_boilerplate_ninja)
  add_custom_target(boilerplate_check_execution_model
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/application-model-check"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_application_model.cmake"
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/application-model-check-multi"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}" "-DCHECK_GENERATOR=Ninja Multi-Config"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_application_model.cmake"
    USES_TERMINAL VERBATIM)

  set(_delivery_check_available TRUE)
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_program(_boilerplate_patchelf patchelf)
    if(NOT _boilerplate_patchelf)
      set(_delivery_check_available FALSE)
    endif()
  endif()
  if(_delivery_check_available)
    add_custom_target(boilerplate_check_delivery
      COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/delivery-check"
        "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_delivery.cmake"
      COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/delivery-check-multi"
        "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}" "-DCHECK_GENERATOR=Ninja Multi-Config"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_delivery.cmake"
      USES_TERMINAL VERBATIM)
  else()
    add_custom_target(boilerplate_check_delivery
      COMMAND ${CMAKE_COMMAND} -E echo
        "boilerplate_check_delivery skipped: patchelf is required for Linux runtime-dependency relocation"
      VERBATIM)
  endif()

  add_custom_target(boilerplate_check_full)
  add_dependencies(boilerplate_check_full boilerplate_check_cmake
    boilerplate_check_execution_model boilerplate_check_delivery)
endif()
if(NOT BOILERPLATE_LIBRARIES_ONLY)
  if(BOILERPLATE_BUILD_APPLICATION)
    boilerplate_add_component(application SOURCE_DIR src FOLDER "components/application")
  endif()
  if(_project_testing AND (BOILERPLATE_BUILD_TESTS OR BOILERPLATE_BUILD_GOOGLE_TESTS) AND BUILD_TESTING)
    boilerplate_add_component(tests SOURCE_DIR tests FOLDER "components/tests")
  endif()
  if(BOILERPLATE_BUILD_EXAMPLES)
    boilerplate_add_component(examples SOURCE_DIR examples FOLDER "components/examples")
  endif()
  if(BOILERPLATE_BUILD_QT_EXAMPLE)
    boilerplate_add_component(qt-example SOURCE_DIR examples/qt FOLDER "components/examples/qt")
  endif()
  if(BOILERPLATE_BUILD_PROPERTY_TESTS)
    boilerplate_add_component(property-tests SOURCE_DIR tests/property_test FOLDER "components/tests/property")
  endif()
  if(BOILERPLATE_BUILD_FUZZERS)
    boilerplate_add_component(byte-fuzzers SOURCE_DIR tests/fuzz_test FOLDER "components/tests/fuzz")
  endif()
  if(BOILERPLATE_BUILD_FUZZTESTS)
    boilerplate_add_component(fuzztests SOURCE_DIR tests/fuzztest FOLDER "components/tests/fuzztest")
  endif()
endif()

set(BOILERPLATE_REFERENCE_SOURCE_DIR "" CACHE PATH "Optional external CMake project; explicit reference target")
set(BOILERPLATE_REFERENCE_CMAKE_ARGS "" CACHE STRING "Reference configuration arguments (CMake list)")
if(BOILERPLATE_REFERENCE_SOURCE_DIR)
  boilerplate_add_reference(reference SOURCE_DIR "${BOILERPLATE_REFERENCE_SOURCE_DIR}"
    CMAKE_ARGS ${BOILERPLATE_REFERENCE_CMAKE_ARGS})
endif()

# Finalizers intentionally run after target registration: package components,
# analysis/format targets, docs, diagnostics and other project-wide workflows
# can inspect the complete build graph without owning target compilation policy.
boilerplate_finalize_project()
