cmake_minimum_required(VERSION 3.28)
project(BoilerplateModulesRegression VERSION 1.0.0 LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES project-minimal)

boilerplate_add_library(math
  SOURCES src/math.cpp src/legacy.cpp src/legacy_more.cpp
  PUBLIC_MODULES src/math.cppm src/math.extra.cppm
  PRIVATE_MODULES src/math.detail.cppm src/math.internal.cppm src/math.alternate.cppm
  INCLUDE_DIR include
  POLICIES minimal)

boilerplate_add_executable(modules_shared
  SOURCES src/main.cpp LIBRARIES math::shared POLICIES minimal)
boilerplate_add_executable(modules_static
  SOURCES src/main.cpp LIBRARIES math::static POLICIES minimal)
# CMake/compiler PCH injection must not precede a module declaration. These
# source-level exclusions preserve PCH and unity for ordinary translation units.
option(MODULES_TEST_PCH_UNITY "Exercise source-level C++ module exclusions" OFF)
if(MODULES_TEST_PCH_UNITY)
  foreach(_target IN ITEMS math_shared math_static)
    boilerplate_enable_pch(${_target} HEADERS <cstdint>)
    set_target_properties(${_target} PROPERTIES UNITY_BUILD ON)
  endforeach()
  set_source_files_properties(
    src/math.cpp src/math.cppm src/math.extra.cppm src/math.detail.cppm
    src/math.internal.cppm src/math.alternate.cppm
    PROPERTIES SKIP_PRECOMPILE_HEADERS ON SKIP_UNITY_BUILD_INCLUSION ON)
endif()

add_test(NAME modules_shared COMMAND modules_shared 42)
add_test(NAME modules_static COMMAND modules_static 42)
boilerplate_finalize_project()
