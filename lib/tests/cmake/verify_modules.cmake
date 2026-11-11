cmake_minimum_required(VERSION 3.26)

if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<scratch build directory>")
endif()
get_filename_component(_toolkit "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
set(_fixtures "${CMAKE_CURRENT_LIST_DIR}/modules")

function(_modules_run)
  execute_process(COMMAND ${ARGV}
    RESULT_VARIABLE _result OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
  if(NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR
      "C++ modules regression failed: ${ARGV}\n--- stdout ---\n${_stdout}\n--- stderr ---\n${_stderr}")
  endif()
endfunction()

if(CMAKE_VERSION VERSION_LESS 3.28)
  set(_unavailable "CMake 3.28 or newer is required")
else()
  find_program(_modules_ninja NAMES ninja)
  if(NOT _modules_ninja)
    set(_unavailable "Ninja is not installed")
  endif()
endif()

if(NOT _unavailable)
  if(NOT CHECK_COMPILER)
    set(_unavailable "CHECK_COMPILER was not supplied")
  else()
    file(REMOVE_RECURSE "${CHECK_BINARY}")
    set(_compiler_arg "-DCMAKE_CXX_COMPILER=${CHECK_COMPILER}")
    # Probe the actual compiler + CMake scanner + generator, not just the compiler
    # version. A newer Clang without clang-scan-deps is not sufficient.
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -S "${_fixtures}/probe"
        -B "${CHECK_BINARY}/probe" -G Ninja "${_compiler_arg}"
      RESULT_VARIABLE _probe_configure OUTPUT_VARIABLE _probe_out ERROR_VARIABLE _probe_err)
    if("${_probe_configure}" STREQUAL "0")
      execute_process(
        COMMAND "${CMAKE_COMMAND}" --build "${CHECK_BINARY}/probe" --parallel 4
        RESULT_VARIABLE _probe_build OUTPUT_VARIABLE _probe_build_out ERROR_VARIABLE _probe_build_err)
    else()
      set(_probe_build "not-run")
    endif()
    if(NOT "${_probe_configure}" STREQUAL "0" OR NOT "${_probe_build}" STREQUAL "0")
      set(_unavailable "compiler/CMake/Ninja cannot build a minimal C++23 named module")
      string(APPEND _unavailable
        "\n${_probe_out}\n${_probe_err}\n${_probe_build_out}\n${_probe_build_err}")
    endif()
  endif()
endif()

if(_unavailable)
  if(CHECK_REQUIRE_MODULES)
    message(FATAL_ERROR "C++ modules required but unavailable: ${_unavailable}")
  endif()
  message(STATUS "SKIP boilerplate_check_modules: ${_unavailable}")
  return()
endif()

file(MAKE_DIRECTORY "${CHECK_BINARY}/source" "${CHECK_BINARY}/consumer"
  "${CHECK_BINARY}/multi-source")
file(COPY "${_fixtures}/project/" DESTINATION "${CHECK_BINARY}/source")
file(COPY "${_fixtures}/project/" DESTINATION "${CHECK_BINARY}/multi-source")
file(COPY "${_fixtures}/consumer/" DESTINATION "${CHECK_BINARY}/consumer")

set(_single "${CHECK_BINARY}/single-build")
set(_source "${CHECK_BINARY}/source")
set(_lib_args
  "-DTOOLKIT_DIR=${_toolkit}"
  "-DBOILERPLATE_CXX_STANDARD=23"
  "-DBOILERPLATE_BUILD_SHARED=ON"
  "-DBOILERPLATE_BUILD_STATIC=ON"
  "-DBOILERPLATE_COMPILER_CACHE=none")
message(STATUS "C++ modules [1/6]: shared/static, public/private modules and partitions")
_modules_run("${CMAKE_COMMAND}" -S "${_source}" -B "${_single}" -G Ninja
  "${_compiler_arg}" ${_lib_args})
_modules_run("${CMAKE_COMMAND}" --build "${_single}" --parallel 4)
_modules_run("${CMAKE_CTEST_COMMAND}" --test-dir "${_single}" --output-on-failure)

# A project that explicitly selects C++17 must fail during configuration,
# rather than producing obscure compiler diagnostics in a later build step.
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${_source}"
    -B "${CHECK_BINARY}/invalid-standard" -G Ninja
    "${_compiler_arg}" ${_lib_args} "-DBOILERPLATE_CXX_STANDARD=17"
  RESULT_VARIABLE _invalid_rc OUTPUT_VARIABLE _invalid_out ERROR_VARIABLE _invalid_err)
if("${_invalid_rc}" STREQUAL "0")
  message(FATAL_ERROR "C++ modules: a C++17 project unexpectedly configured")
endif()
string(FIND "${_invalid_out}${_invalid_err}" "C++ modules require CXX_STANDARD >= 20"
  _invalid_message)
if(_invalid_message EQUAL -1)
  message(FATAL_ERROR
    "C++17 rejection did not report the expected modules diagnostic:
${_invalid_out}
${_invalid_err}")
endif()

if(CMAKE_HOST_WIN32)
  set(_exe .exe)
else()
  set(_exe "")
endif()

message(STATUS "C++ modules [2/6]: incremental rebuild after changing an exported interface")
set(_interface_file "${_source}/src/math.extra.cppm")
file(READ "${_interface_file}" _before)
string(REPLACE "return 2;" "return 3;" _after "${_before}")
if(_before STREQUAL _after)
  message(FATAL_ERROR "C++ modules fixture changed: cannot replace exported correction()")
endif()
file(WRITE "${_interface_file}" "${_after}")
_modules_run("${CMAKE_COMMAND}" --build "${_single}" --parallel 4)
_modules_run("${_single}/modules_shared${_exe}" 43)
_modules_run("${_single}/modules_static${_exe}" 43)

message(STATUS "C++ modules [3/6]: dynamic dependency graph after changing an import")
set(_implementation_file "${_source}/src/math.cpp")
file(READ "${_implementation_file}" _before)
string(REPLACE "import math.internal;" "import math.alternate;" _after "${_before}")
if(_before STREQUAL _after)
  message(FATAL_ERROR "C++ modules fixture changed: cannot rewrite module import")
endif()
file(WRITE "${_implementation_file}" "${_after}")
_modules_run("${CMAKE_COMMAND}" --build "${_single}" --parallel 4)
_modules_run("${_single}/modules_shared${_exe}" 48)
_modules_run("${_single}/modules_static${_exe}" 48)

message(STATUS "C++ modules [4/6]: install, relocation and find_package (both variants)")
_modules_run("${CMAKE_COMMAND}" --install "${_single}"
  --prefix "${CHECK_BINARY}/installed")
file(RENAME "${CHECK_BINARY}/installed" "${CHECK_BINARY}/relocated")
set(_installed_modules "${CHECK_BINARY}/relocated/include/math/modules/src")
foreach(_public IN ITEMS math.cppm math.extra.cppm)
  if(NOT EXISTS "${_installed_modules}/${_public}")
    message(FATAL_ERROR "Public C++ module missing from installed package: ${_public}")
  endif()
endforeach()
foreach(_private IN ITEMS math.detail.cppm math.internal.cppm math.alternate.cppm)
  if(EXISTS "${_installed_modules}/${_private}")
    message(FATAL_ERROR "Private C++ module leaked into installed package: ${_private}")
  endif()
endforeach()
# On Windows the installed shared-library DLL is in <prefix>/bin, not next to
# the separately built consumer executable.
if(CMAKE_HOST_WIN32)
  set(ENV{PATH} "${CHECK_BINARY}/relocated/bin;$ENV{PATH}")
endif()
_modules_run("${CMAKE_COMMAND}" -S "${CHECK_BINARY}/consumer"
  -B "${CHECK_BINARY}/consumer-build" -G Ninja
  "${_compiler_arg}" "-DCMAKE_PREFIX_PATH=${CHECK_BINARY}/relocated")
_modules_run("${CMAKE_COMMAND}" --build "${CHECK_BINARY}/consumer-build" --parallel 4)
_modules_run("${CMAKE_CTEST_COMMAND}" --test-dir "${CHECK_BINARY}/consumer-build"
  --output-on-failure)

message(STATUS "C++ modules [5/6]: C++20 Ninja Multi-Config Debug + Release")
set(_multi_args ${_lib_args})
list(REMOVE_ITEM _multi_args "-DBOILERPLATE_CXX_STANDARD=23")
list(APPEND _multi_args "-DBOILERPLATE_CXX_STANDARD=20")
_modules_run("${CMAKE_COMMAND}" -S "${CHECK_BINARY}/multi-source"
  -B "${CHECK_BINARY}/multi-build" -G "Ninja Multi-Config"
  "${_compiler_arg}" ${_multi_args})
foreach(_config IN ITEMS Debug Release)
  _modules_run("${CMAKE_COMMAND}" --build "${CHECK_BINARY}/multi-build"
    --config "${_config}" --parallel 4)
  _modules_run("${CMAKE_CTEST_COMMAND}" --test-dir "${CHECK_BINARY}/multi-build"
    -C "${_config}" --output-on-failure)
endforeach()
message(STATUS "C++ modules [6/6]: module-safe PCH and unity-build coexistence")
_modules_run("${CMAKE_COMMAND}" -S "${CHECK_BINARY}/multi-source"
  -B "${CHECK_BINARY}/interaction-build" -G Ninja
  "${_compiler_arg}" ${_lib_args} "-DMODULES_TEST_PCH_UNITY=ON")
_modules_run("${CMAKE_COMMAND}" --build "${CHECK_BINARY}/interaction-build" --parallel 4)
_modules_run("${CMAKE_CTEST_COMMAND}" --test-dir "${CHECK_BINARY}/interaction-build"
  --output-on-failure)
message(STATUS "PASS boilerplate_check_modules: module partitions, incremental imports, shared/static, relocation, multi-config, PCH/unity exclusions")
