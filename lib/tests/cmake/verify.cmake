# The self-contained CMake harness records a reproducible matrix.
run("${CMAKE_COMMAND}" --build "${CHECK_BINARY}/build" --target run_fixture_harness)

set(
  _harness_summary
  "${CHECK_BINARY}/build/harness-results/Release/fixture_harness/summary.json"
)

if(NOT EXISTS "${_harness_summary}")
  message(FATAL_ERROR "CMake harness did not produce summary.json")
endif()

file(READ "${_harness_summary}" _harness_json)

foreach(_case IN ITEMS one two)
  string(
    JSON _count
    ERROR_VARIABLE _case_error
    GET "${_harness_json}"
    cases ${_case} metrics value count
  )

  string(
    JSON _checksum
    ERROR_VARIABLE _inv_error
    GET "${_harness_json}"
    cases ${_case} invariants checksum
  )

  if(_case_error OR NOT _count EQUAL 2)
    message(
      FATAL_ERROR
      "CMake harness did not run measured case ${_case}: ${_harness_json}"
    )
  endif()

  if(_inv_error OR NOT _checksum STREQUAL "42")
    message(
      FATAL_ERROR
      "CMake harness did not preserve ${_case} checksum invariant: ${_harness_json}"
    )
  endif()
endforeach()
