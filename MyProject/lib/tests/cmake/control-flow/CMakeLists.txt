cmake_minimum_required(VERSION 3.26)
project(ControlFlowFixture LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
set(TEST_POLICY cfi CACHE STRING "Policy under test")
set(TEST_LTO thin CACHE STRING "LTO override")
set(TEST_DIAGNOSTICS OFF CACHE BOOL "CFI diagnostics")
set(TEST_SANITIZER none CACHE STRING "Additional sanitizer")
set(TEST_KIND static CACHE STRING "Library kind")
if(TEST_EDIT_AND_CONTINUE)
  set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT EditAndContinue)
endif()
set(_overrides)
if(DEFINED TEST_CFI)
  list(APPEND _overrides CFI "${TEST_CFI}")
endif()
if(DEFINED TEST_CFG)
  list(APPEND _overrides WINDOWS_CFG "${TEST_CFG}")
endif()

set(FLOW_BUILD_STATIC OFF CACHE BOOL "" FORCE)
set(FLOW_BUILD_SHARED OFF CACHE BOOL "" FORCE)
string(TOUPPER "${TEST_KIND}" _kind)
set(FLOW_BUILD_${_kind} ON CACHE BOOL "" FORCE)
boilerplate_add_library(flow SOURCES flow.cpp INCLUDE_DIR include
  POLICIES minimal ${TEST_POLICY}
  POLICY_OPTIONS LTO_MODE "${TEST_LTO}" CFI_DIAGNOSTICS "${TEST_DIAGNOSTICS}"
    SANITIZER "${TEST_SANITIZER}" ${_overrides})

# An ordinary consumer must receive the static archive's final-link requirements.
boilerplate_get_target_setting(flow_${TEST_KIND} CFI _cfi)
boilerplate_get_target_setting(flow_${TEST_KIND} WINDOWS_CFG _cfg)
set(_consumer_policies minimal)
if(_cfg AND TEST_KIND STREQUAL "shared")
  list(APPEND _consumer_policies windows-cfg)
endif()
boilerplate_add_executable(flow_probe SOURCES main.cpp LIBRARIES flow::flow POLICIES ${_consumer_policies})
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/probe-path.txt" CONTENT "$<TARGET_FILE:flow_probe>")
add_test(NAME valid_calls COMMAND flow_probe 0)
if(_cfi STREQUAL "cfi" OR _cfi STREQUAL "cfi-icall")
  add_test(NAME reject_invalid_icall COMMAND "${CMAKE_COMMAND}"
    "-DBINARY=$<TARGET_FILE:flow_probe>" -DCASE=1 "-DDIAGNOSTICS=${TEST_DIAGNOSTICS}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_failure.cmake")
endif()
if(_cfi STREQUAL "cfi" OR _cfi STREQUAL "cfi-vcall")
  add_test(NAME reject_invalid_vcall COMMAND "${CMAKE_COMMAND}"
    "-DBINARY=$<TARGET_FILE:flow_probe>" -DCASE=2 "-DDIAGNOSTICS=${TEST_DIAGNOSTICS}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_failure.cmake")
endif()
if(_cfg)
  find_program(DUMPBIN dumpbin REQUIRED)
  add_test(NAME cfg_image_metadata COMMAND "${CMAKE_COMMAND}"
    "-DBINARY=$<TARGET_FILE:flow_probe>" "-DDUMPBIN=${DUMPBIN}"
    -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_cfg.cmake")
  if(TEST_KIND STREQUAL "shared")
    add_test(NAME cfg_dll_metadata COMMAND "${CMAKE_COMMAND}"
      "-DBINARY=$<TARGET_FILE:flow_shared>" "-DDUMPBIN=${DUMPBIN}"
      -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_cfg.cmake")
  endif()
endif()

# Composition must remain inspectable and resettable without applying flags.
add_executable(reset_probe EXCLUDE_FROM_ALL main.cpp)
boilerplate_configure_target(reset_probe POLICIES runtime-hardened windows-cfg minimal)
foreach(_key IN ITEMS CFI WINDOWS_CFG CFI_DIAGNOSTICS LTO_MODE HARDENING)
  boilerplate_get_target_setting(reset_probe ${_key} _value)
  if(_key MATCHES "^(CFI|LTO_MODE)$")
    if(NOT _value STREQUAL "none")
      message(FATAL_ERROR "minimal did not reset ${_key}")
    endif()
  elseif(_value)
    message(FATAL_ERROR "minimal did not reset ${_key}")
  endif()
endforeach()
if(TEST_POLICY STREQUAL "runtime-hardened")
  boilerplate_get_target_setting(flow_${TEST_KIND} HARDENING _hardening)
  if(NOT _hardening OR NOT _cfi STREQUAL "cfi")
    message(FATAL_ERROR "runtime-hardened lost hardening or CFI")
  endif()
endif()
