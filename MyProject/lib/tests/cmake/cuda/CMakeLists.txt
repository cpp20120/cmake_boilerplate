cmake_minimum_required(VERSION 3.26)
project(CudaPolicyProbe VERSION 1.0 LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
if(TEST_MODE STREQUAL "no-language")
  boilerplate_add_executable(missing SOURCES main.cpp POLICIES cuda)
  return()
endif()
boilerplate_project(CAPABILITIES project-minimal cuda)
if(TEST_MODE STREQUAL "invalid")
  set(_bad_options)
  if(BAD_STANDARD)
    list(APPEND _bad_options CUDA_STANDARD "${BAD_STANDARD}")
  endif()
  boilerplate_add_executable(invalid SOURCES main.cpp POLICIES runtime-cuda ${BAD_POLICY}
    POLICY_OPTIONS ${_bad_options})
  return()
endif()
set(BOILERPLATE_BUILD_SHARED ON)
set(BOILERPLATE_BUILD_STATIC ON)
boilerplate_add_library(gpu_math
  SOURCES kernel.cu device.cu host.cpp INCLUDE_DIR include
  POLICIES runtime-cuda
  SHARED_POLICIES cuda-profiled
  STATIC_POLICIES cuda-debug)
foreach(_kind IN ITEMS shared static)
  boilerplate_add_executable(cuda_${_kind} SOURCES main.cpp
    LIBRARIES gpu_math::${_kind} POLICIES runtime-cuda)
  add_test(NAME cuda_${_kind}_host COMMAND cuda_${_kind})
endforeach()
boilerplate_add_executable(cuda_direct SOURCES direct.cu device.cu POLICIES runtime-cuda cuda-fast-math
  POLICY_OPTIONS CUDA_RUNTIME_LIBRARY Shared)
add_test(NAME cuda_direct_host COMMAND cuda_direct)
boilerplate_add_executable(cpu_only SOURCES cpu.cpp POLICIES cuda minimal)
get_target_property(_cpu_cuda cpu_only CUDA_STANDARD)
if(_cpu_cuda)
  # CUDA_STANDARD may be initialized by the project; no CUDA flags may leak.
  get_target_property(_cpu_flags cpu_only COMPILE_OPTIONS)
  if(_cpu_flags MATCHES "generate-line-info|device-debug|use_fast_math")
    message(FATAL_ERROR "minimal did not reset CUDA policy")
  endif()
endif()
boilerplate_finalize_project()
