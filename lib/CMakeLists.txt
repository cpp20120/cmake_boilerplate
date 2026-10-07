cmake_minimum_required(VERSION 3.26)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  include("${CMAKE_CURRENT_LIST_DIR}/cmake/Bootstrap.cmake")
  boilerplate_bootstrap()
  project(BoilerplateLibraries VERSION 1.0.0 LANGUAGES CXX)
  include(CTest)
endif()
include("${CMAKE_CURRENT_LIST_DIR}/cmake/Boilerplate.cmake")
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR AND
   (COMMAND boilerplate_add_application OR COMMAND boilerplate_add_host OR COMMAND boilerplate_add_plugin))
  message(FATAL_ERROR "Standalone lib slice must not load application/hosting/plugin APIs")
endif()
get_property(_boilerplate_project_configured GLOBAL PROPERTY BOILERPLATE_PROJECT_CONFIGURED)
if(NOT _boilerplate_project_configured)
  boilerplate_project(
    TOP_LEVEL_CAPABILITIES compile-commands testing build-info diagnostics
    EMBEDDED_CAPABILITIES project-minimal)
endif()

add_subdirectory(library1)
add_subdirectory(library2)

option(BOILERPLATE_GENERATE_VCPKG_PORTS "Generate example vcpkg overlay ports" OFF)
if(BOILERPLATE_GENERATE_VCPKG_PORTS)
  foreach(_library IN ITEMS library1 library2)
    boilerplate_vcpkg_port(${_library}
      VERSION 1.0.0
      DESCRIPTION "Boilerplate ${_library} example"
      SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.."
      SOURCE_SUBDIR "lib/${_library}"
      SPDX_LICENSE MIT
      LICENSE_FILE LICENSE
      PACKAGES ${_library})
  endforeach()
endif()


# The two example libraries intentionally exercise different consumer-local
# policy packs. Keep this as a configure-time regression so future refactors do
# not collapse them back into one hidden global policy.
foreach(_kind IN ITEMS shared static)
  if(TARGET library1_${_kind})
    boilerplate_get_target_setting(library1_${_kind} WARNINGS_AS_ERRORS _lib1_werror)
    boilerplate_get_target_setting(library1_${_kind} HARDENING _lib1_hardening)
    boilerplate_get_target_setting(library1_${_kind} UNITY_BUILD _lib1_unity)
    if(NOT _lib1_werror)
      message(FATAL_ERROR "library1 local policy pack lost warnings-as-errors")
    endif()
    if(_kind STREQUAL "shared" AND NOT _lib1_hardening)
      message(FATAL_ERROR "library1 shared variant lost its hardening policy")
    elseif(_kind STREQUAL "static" AND NOT _lib1_unity)
      message(FATAL_ERROR "library1 static variant lost its unity policy")
    endif()
  endif()

  if(TARGET library2_${_kind})
    boilerplate_get_target_setting(library2_${_kind} FRAME_POINTERS _lib2_fp)
    boilerplate_get_target_setting(library2_${_kind} HARDENING _lib2_hardening)
    boilerplate_get_target_setting(library2_${_kind} REPRODUCIBLE _lib2_repro)
    if(NOT _lib2_fp)
      message(FATAL_ERROR "library2 local policy pack lost frame pointers")
    endif()
    if(_kind STREQUAL "shared" AND NOT _lib2_hardening)
      message(FATAL_ERROR "library2 shared variant lost its hardening policy")
    elseif(_kind STREQUAL "static" AND NOT _lib2_repro)
      message(FATAL_ERROR "library2 static variant lost its reproducible policy")
    endif()
  endif()
endforeach()
boilerplate_project_has_capability(testing _boilerplate_testing_enabled)

# Small dependency-free checks exercise both real library variants.
if(_boilerplate_testing_enabled AND BOILERPLATE_BUILD_TESTS AND BUILD_TESTING)
  add_subdirectory(tests/smoke)
endif()
if(BOILERPLATE_BUILD_BENCHMARKS OR BOILERPLATE_BUILD_GOOGLE_BENCHMARKS)
  add_subdirectory(bench)
endif()

if(_boilerplate_testing_enabled AND BOILERPLATE_BUILD_GOOGLE_TESTS AND BUILD_TESTING)
  boilerplate_add_googletest(lib1_test SOURCES tests/lib1_test/lib_test.cpp LIBRARIES library1::library1)
  boilerplate_add_googletest(lib2_test SOURCES tests/lib2_test/lib_test.cpp LIBRARIES library2::library2)
endif()

# Explicit infrastructure regression checks; never part of the default build.
find_program(_boilerplate_ninja ninja)
if(_boilerplate_ninja)
  find_program(_boilerplate_clang clang++)
  set(_check_clang)
  if(_boilerplate_clang)
    set(_check_clang "-DCHECK_CLANG=${_boilerplate_clang}")
  endif()
  add_custom_target(boilerplate_check_cmake
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/vcpkg-check"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_vcpkg.cmake"
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/cmake-check"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_bootstrap.cmake"
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/cmake-check"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}" ${_check_clang}
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify.cmake"
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/cmake-check"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_examples.cmake"
    USES_TERMINAL VERBATIM)

  add_custom_target(boilerplate_check_cuda
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/cuda-check"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}"
      "-DCHECK_CUDA_COMPILER=${CMAKE_CUDA_COMPILER}"
      "-DCHECK_CUDA_HOST_COMPILER=${CMAKE_CUDA_HOST_COMPILER}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_cuda.cmake"
    USES_TERMINAL VERBATIM)
  add_custom_target(boilerplate_check_shaders
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/shader-check"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_shaders.cmake"
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/shader-check-multi"
      "-DCHECK_COMPILER=${CMAKE_CXX_COMPILER}" "-DCHECK_GENERATOR=Ninja Multi-Config"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_shaders.cmake"
    USES_TERMINAL VERBATIM)

  set(_control_flow_compiler)
  if(WIN32 AND MSVC)
    set(_control_flow_compiler "${CMAKE_CXX_COMPILER}")
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND _boilerplate_clang)
    find_program(_boilerplate_lld ld.lld)
    if(_boilerplate_lld)
      set(_control_flow_compiler "${_boilerplate_clang}")
    endif()
  endif()
  if(_control_flow_compiler)
    add_custom_target(boilerplate_check_control_flow
      COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/control-flow-check"
        "-DCHECK_COMPILER=${_control_flow_compiler}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/cmake/verify_control_flow.cmake"
      USES_TERMINAL VERBATIM)
  endif()
endif()

if(_boilerplate_testing_enabled AND BOILERPLATE_BUILD_TESTS AND BUILD_TESTING)
  add_test(NAME boilerplate_harness_checks
    COMMAND ${CMAKE_COMMAND} "-DCHECK_BINARY=${CMAKE_BINARY_DIR}/harness-check"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/tests/harness/verify.cmake")
  set_tests_properties(boilerplate_harness_checks PROPERTIES LABELS "build;harness" TIMEOUT 20)
endif()

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  boilerplate_finalize_project()
endif()
