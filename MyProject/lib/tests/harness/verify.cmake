cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "CHECK_BINARY is required")
endif()
file(MAKE_DIRECTORY "${CHECK_BINARY}/work dir")
file(WRITE "${CHECK_BINARY}/work dir/cwd-marker" "fixture")
foreach(_mode IN ITEMS success fail timeout)
  set(_root "${CHECK_BINARY}/${_mode}")
  file(REMOVE_RECURSE "${_root}")
  file(WRITE "${CHECK_BINARY}/${_mode}.cmake"
    "set(EXECUTABLE [==[${CMAKE_COMMAND}]==])\n"
    "set(ARGS [==[-DMODE=${_mode};-DWORDS=two words;-P;${CMAKE_CURRENT_LIST_DIR}/workload.cmake]==])\n"
    "set(ENVIRONMENT [==[HARNESS_FIXTURE=space value]==])\n"
    "set(WORKING_DIRECTORY [==[${CHECK_BINARY}/work dir]==])\n"
    "set(RESULT_ROOT [==[${_root}]==])\nset(TIMEOUT 1)\nset(REPEATS 2)\nset(WARMUP 1)\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" "-DRUN_CONFIG=${CHECK_BINARY}/${_mode}.cmake"
    -P "${CMAKE_CURRENT_LIST_DIR}/../../cmake/benchmark/RunWorkload.cmake"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
  file(GLOB _reports "${_root}/*/result.json")
  list(LENGTH _reports _count)
  if(NOT _count EQUAL 1)
    message(FATAL_ERROR "Missing report for ${_mode}: ${_stdout}\n${_stderr}")
  endif()
  list(GET _reports 0 _report)
  file(READ "${_report}" _json)
  string(JSON _status GET "${_json}" status)
  string(JSON _runs LENGTH "${_json}" runs)
  if(_mode STREQUAL "success")
    if(NOT _result EQUAL 0 OR NOT _status STREQUAL "passed" OR NOT _runs EQUAL 3)
      message(FATAL_ERROR "Success/repetitions fixture failed: ${_json}")
    endif()
    string(JSON _median GET "${_json}" summary median_us)
    if(_median LESS 0)
      message(FATAL_ERROR "Negative duration")
    endif()
  elseif(_result EQUAL 0 OR NOT _status STREQUAL "failed" OR NOT _runs EQUAL 1)
    message(FATAL_ERROR "Failure/timeout swallowed: ${_json}")
  endif()
endforeach()
message(STATUS "Harness arguments, environment, cwd, repeats, JSON, failure and timeout passed")
# Comparison refuses failed reports and enforces an explicitly requested threshold.
file(GLOB _success "${CHECK_BINARY}/success/*/result.json")
list(GET _success 0 _base)
file(READ "${_base}" _json)
string(JSON _median GET "${_json}" summary median_us)
math(EXPR _slower "${_median}*2")
string(JSON _json SET "${_json}" summary median_us ${_slower})
file(WRITE "${CHECK_BINARY}/slower.json" "${_json}")
execute_process(COMMAND "${CMAKE_COMMAND}" "-DBASELINE=${_base}" "-DCANDIDATE=${_base}"
  -DMAX_REGRESSION_PERCENT=0 -P "${CMAKE_CURRENT_LIST_DIR}/../../cmake/benchmark/CompareResults.cmake"
  RESULT_VARIABLE _equal_result OUTPUT_QUIET ERROR_QUIET)
execute_process(COMMAND "${CMAKE_COMMAND}" "-DBASELINE=${_base}" "-DCANDIDATE=${CHECK_BINARY}/slower.json"
  -DMAX_REGRESSION_PERCENT=10 -P "${CMAKE_CURRENT_LIST_DIR}/../../cmake/benchmark/CompareResults.cmake"
  RESULT_VARIABLE _slower_result OUTPUT_QUIET ERROR_QUIET)
if(NOT _equal_result EQUAL 0 OR _slower_result EQUAL 0)
  message(FATAL_ERROR "Comparison threshold handling failed")
endif()
