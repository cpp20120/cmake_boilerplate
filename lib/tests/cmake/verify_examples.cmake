cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<temporary build directory>")
endif()
get_filename_component(_lib_source "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

function(run)
  execute_process(COMMAND ${ARGV} RESULT_VARIABLE result OUTPUT_VARIABLE output ERROR_VARIABLE error)
  if(NOT result EQUAL 0)
    message(FATAL_ERROR "Command failed: ${ARGV}\n${output}\n${error}")
  endif()
endfunction()

set(_compiler_args)
if(CHECK_COMPILER)
  list(APPEND _compiler_args "-DCMAKE_CXX_COMPILER=${CHECK_COMPILER}")
endif()

set(_build "${CHECK_BINARY}/example-libraries")
set(_prefix "${CHECK_BINARY}/example-prefix")
set(_relocated "${CHECK_BINARY}/example-relocated")
run("${CMAKE_COMMAND}" -S "${_lib_source}" -B "${_build}" -G Ninja
  ${_compiler_args}
  -DBOILERPLATE_BUILD_SHARED=ON
  -DBOILERPLATE_BUILD_STATIC=ON
  -DBOILERPLATE_BUILD_TESTS=ON
  -DBUILD_TESTING=ON)
run("${CMAKE_COMMAND}" --build "${_build}" --parallel 2)
run("${CMAKE_CTEST_COMMAND}" --test-dir "${_build}" --output-on-failure)
run("${CMAKE_COMMAND}" --install "${_build}" --prefix "${_prefix}")

file(REMOVE_RECURSE "${_relocated}")
file(RENAME "${_prefix}" "${_relocated}")
run("${CMAKE_COMMAND}" -S "${CMAKE_CURRENT_LIST_DIR}/example-consumer"
  -B "${CHECK_BINARY}/example-consumer" -G Ninja
  "-DCMAKE_PREFIX_PATH=${_relocated}" ${_compiler_args})
run("${CMAKE_COMMAND}" --build "${CHECK_BINARY}/example-consumer" --parallel 2)
run("${CMAKE_CTEST_COMMAND}" --test-dir "${CHECK_BINARY}/example-consumer" --output-on-failure)
message(STATUS "Independent library policy packs and installed dependency propagation passed")
