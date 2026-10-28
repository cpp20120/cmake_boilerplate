cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<fresh temporary directory>")
endif()
get_filename_component(_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
get_filename_component(CHECK_BINARY "${CHECK_BINARY}" ABSOLUTE)
if(EXISTS "${CHECK_BINARY}")
  message(FATAL_ERROR "Use a fresh CHECK_BINARY directory")
endif()
set(_fixture "${_root}/tests/cmake/dashboard-fixture")
function(run)
  execute_process(COMMAND ${ARGV} RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _rc STREQUAL "0")
    message(FATAL_ERROR "Failed: ${ARGV}\n${_out}\n${_err}")
  endif()
endfunction()
function(reject expected)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _rc OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_rc STREQUAL "0" OR NOT "${_out}\n${_err}" MATCHES "${expected}")
    message(FATAL_ERROR "Expected '${expected}' rejection: ${ARGN}\n${_out}\n${_err}")
  endif()
endfunction()
function(report binary part output)
  file(STRINGS "${binary}/Testing/TAG" _tag LIMIT_COUNT 1)
  set(_path "${binary}/Testing/${_tag}/${part}.xml")
  if(NOT EXISTS "${_path}")
    message(FATAL_ERROR "Missing ${part}.xml: ${_path}")
  endif()
  set(${output} "${_path}" PARENT_SCOPE)
endfunction()

set(_disabled "${CHECK_BINARY}/disabled")
run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_disabled}" -G Ninja
  "-DBOILERPLATE_ROOT=${_root}" -DDASHBOARD_FIXTURE_DISABLED=ON)
if(EXISTS "${_disabled}/boilerplate-dashboard.cmake")
  message(FATAL_ERROR "Disabled dashboard generated a script")
endif()
set(_local "${CHECK_BINARY}/local")
run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_local}" -G Ninja
  "-DBOILERPLATE_ROOT=${_root}" -DBOILERPLATE_DASHBOARD_SUBMIT=OFF)
run("${CMAKE_COMMAND}" --build "${_local}" --target boilerplate_dashboard)
foreach(_part IN ITEMS Configure Build Test)
  report("${_local}" "${_part}" _xml)
endforeach()
file(READ "${_xml}" _tests)
if(NOT _tests MATCHES "dashboard_pass" OR _tests MATCHES "dashboard_fail")
  message(FATAL_ERROR "Unexpected local dashboard tests")
endif()
file(STRINGS "${_local}/Testing/TAG" _tag LIMIT_COUNT 1)
if(EXISTS "${_local}/Testing/${_tag}/Coverage.xml" OR
   EXISTS "${_local}/Testing/${_tag}/Submit.xml")
  message(FATAL_ERROR "Disabled coverage/submission created dashboard artifacts")
endif()
run("${CMAKE_COMMAND}" --build "${_local}" --target boilerplate_dashboard)
report("${_local}" Test _xml)
file(READ "${_xml}" _tests)
string(REGEX MATCHALL "<Name>dashboard_pass</Name>" _pass_entries "${_tests}")
list(LENGTH _pass_entries _pass_count)
if(NOT _pass_count EQUAL 1)
  message(FATAL_ERROR "Repeated dashboard mixed Test.xml entries")
endif()
run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_local}" -DDASHBOARD_FIXTURE_FAIL=ON)
reject("Dashboard pipeline failed" "${CMAKE_COMMAND}" --build "${_local}" --target boilerplate_dashboard)
report("${_local}" Test _xml)
file(READ "${_xml}" _tests)
if(NOT _tests MATCHES "dashboard_pass" OR NOT _tests MATCHES "dashboard_fail")
  message(FATAL_ERROR "Failed dashboard omitted passing or failing test")
endif()
reject("Dashboard submission requires" "${CMAKE_COMMAND}" -S "${_fixture}"
  -B "${CHECK_BINARY}/invalid-url" -G Ninja "-DBOILERPLATE_ROOT=${_root}"
  -DBOILERPLATE_DASHBOARD_SUBMIT=ON -DBOILERPLATE_DASHBOARD_URL=bad)
reject("Dashboard submission requires" "${CMAKE_COMMAND}" -S "${_fixture}"
  -B "${CHECK_BINARY}/missing-project" -G Ninja "-DBOILERPLATE_ROOT=${_root}"
  -DBOILERPLATE_DASHBOARD_SUBMIT=ON
  -DBOILERPLATE_DASHBOARD_URL=https://example.invalid/submit.php?project=Example
  -DBOILERPLATE_DASHBOARD_PROJECT=)

find_program(_gxx NAMES g++)
if(_gxx)
  set(_coverage "${CHECK_BINARY}/coverage")
  run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coverage}" -G Ninja
    "-DBOILERPLATE_ROOT=${_root}" "-DCMAKE_CXX_COMPILER=${_gxx}"
    -DBOILERPLATE_COVERAGE=ON -DBOILERPLATE_DASHBOARD_COVERAGE=ON)
  run("${CMAKE_COMMAND}" --build "${_coverage}" --target boilerplate_dashboard)
  report("${_coverage}" Coverage _xml)
  file(READ "${_xml}" _coverage_body)
  if(NOT _coverage_body MATCHES "<LOCTested>[1-9][0-9]*</LOCTested>")
    message(FATAL_ERROR "Coverage.xml lacks measured coverage")
  endif()

  # Coverage ON -> OFF in the same CTest TAG must not preserve old XML.
  # The run normally stays within the same minute. In the rare event that it
  # crosses a minute boundary, repeat the OFF run with a sentinel in the new
  # current TAG to deterministically exercise directory cleanup.
  file(STRINGS "${_coverage}/Testing/TAG" _covered_tag LIMIT_COUNT 1)
  run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_coverage}"
    -DBOILERPLATE_DASHBOARD_COVERAGE=OFF)
  run("${CMAKE_COMMAND}" --build "${_coverage}" --target boilerplate_dashboard)
  file(STRINGS "${_coverage}/Testing/TAG" _off_tag LIMIT_COUNT 1)
  if(NOT _off_tag STREQUAL _covered_tag)
    file(WRITE "${_coverage}/Testing/${_off_tag}/Coverage.xml" "stale coverage must be removed")
    run("${CMAKE_COMMAND}" --build "${_coverage}" --target boilerplate_dashboard)
    file(STRINGS "${_coverage}/Testing/TAG" _off_tag LIMIT_COUNT 1)
  endif()
  if(EXISTS "${_coverage}/Testing/${_off_tag}/Coverage.xml")
    message(FATAL_ERROR "Old Coverage.xml survived a dashboard run with coverage OFF")
  endif()
  # Also ensure disabled/unexecuted stages do not leave other report XML behind.
  file(WRITE "${_coverage}/Testing/${_off_tag}/Update.xml" "stale update")
  file(WRITE "${_coverage}/Testing/${_off_tag}/DynamicAnalysis.xml" "stale memcheck")
  file(WRITE "${_coverage}/Testing/${_off_tag}/CoverageLog-0.xml" "stale coverage details")
  run("${CMAKE_COMMAND}" --build "${_coverage}" --target boilerplate_dashboard)
  file(STRINGS "${_coverage}/Testing/TAG" _clean_tag LIMIT_COUNT 1)
  foreach(_part IN ITEMS Update DynamicAnalysis CoverageLog-0 Coverage)
    if(EXISTS "${_coverage}/Testing/${_clean_tag}/${_part}.xml")
      message(FATAL_ERROR "Stale ${_part}.xml survived a dashboard run")
    endif()
  endforeach()
endif()
set(_multi "${CHECK_BINARY}/multi")
run("${CMAKE_COMMAND}" -S "${_fixture}" -B "${_multi}" -G "Ninja Multi-Config"
  "-DBOILERPLATE_ROOT=${_root}" -DBOILERPLATE_DASHBOARD_CONFIGURATION=Release)
run("${CMAKE_COMMAND}" --build "${_multi}" --config Release --target boilerplate_dashboard)
report("${_multi}" Test _xml)
file(READ "${_xml}" _tests)
# CTest can serialize Windows executable paths with backslash separators.
# Normalize the XML text before checking the multi-config executable path.
string(REPLACE "\\" "/" _normalized_tests "${_tests}")
if(NOT _normalized_tests MATCHES "Release/dashboard_fixture(\\.exe)?")
  string(REGEX MATCHALL "<FullCommandLine>[^<]*</FullCommandLine>"
    _test_commands "${_tests}")
  message(FATAL_ERROR
    "Multi-config dashboard did not run Release executable.\n"
    "Test commands: ${_test_commands}\n"
    "CTest report: ${_xml}")
endif()
message(STATUS "Dashboard regression checks passed")
