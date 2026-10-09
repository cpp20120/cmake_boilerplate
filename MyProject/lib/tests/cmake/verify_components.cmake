cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<temporary test directory>")
endif()
get_filename_component(_toolkit "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
get_filename_component(CHECK_BINARY "${CHECK_BINARY}" ABSOLUTE)
if(EXISTS "${CHECK_BINARY}")
  file(REMOVE_RECURSE "${CHECK_BINARY}")
endif()
set(_source "${CHECK_BINARY}/source")
set(_build "${CHECK_BINARY}/build")
file(MAKE_DIRECTORY "${_source}/component")

# One reusable component source is instantiated into many binary directories.
# This keeps the fixture tiny while exercising the same component registry,
# inherited directory property and IDE-folder path used by a 100+ subtree tree.
file(WRITE "${_source}/component/CMakeLists.txt" [=[
get_property(_component DIRECTORY PROPERTY BOILERPLATE_COMPONENT)
if(NOT _component)
  message(FATAL_ERROR "Component identity was not inherited")
endif()
add_library(target_${_component} INTERFACE)
boilerplate_register_target(target_${_component})
get_target_property(_owned target_${_component} BOILERPLATE_COMPONENT)
if(NOT _owned STREQUAL _component)
  message(FATAL_ERROR "Target ownership mismatch: ${_owned} vs ${_component}")
endif()
]=])

file(WRITE "${_source}/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.26)
project(ComponentScaleFixture LANGUAGES CXX)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES project-minimal diagnostics)
foreach(_i RANGE 1 128)
  set(_name "component_${_i}")
  boilerplate_add_component("${_name}"
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/component"
    BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/components/${_name}"
    FOLDER "components/${_name}")
endforeach()
boilerplate_list_components(_components)
list(LENGTH _components _component_count)
if(NOT _component_count EQUAL 128)
  message(FATAL_ERROR "Expected 128 components, got ${_component_count}")
endif()
boilerplate_component_targets(component_64 _middle_targets)
if(NOT target_component_64 IN_LIST _middle_targets)
  message(FATAL_ERROR "Middle component lost its target: ${_middle_targets}")
endif()
boilerplate_finalize_project()
]=])

execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_source}" -B "${_build}" -G Ninja
  "-DTOOLKIT_DIR=${_toolkit}"
  RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _rc STREQUAL "0")
  message(FATAL_ERROR "128-component configure failed:\n${_out}\n${_err}")
endif()
file(READ "${_build}/boilerplate-project.txt" _summary)
foreach(_expected IN ITEMS "component_1: targets=1" "component_64: targets=1" "component_128: targets=1")
  string(FIND "${_summary}" "${_expected}" _index)
  if(_index LESS 0)
    message(FATAL_ERROR "Scale diagnostics lost '${_expected}'")
  endif()
endforeach()
message(STATUS "128-component workspace configure and ownership checks passed")
