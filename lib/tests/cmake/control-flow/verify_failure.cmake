execute_process(COMMAND "${BINARY}" "${CASE}" RESULT_VARIABLE _result
  OUTPUT_VARIABLE _out ERROR_VARIABLE _err TIMEOUT 10)
if("${_result}" STREQUAL "0" OR NOT _err MATCHES "CONTROL_FLOW_PROBE_READY" OR
    _err MATCHES "CONTROL_FLOW_PROBE_FINISHED" OR "${_result}" MATCHES "timeout")
  message(FATAL_ERROR "Expected a CFI rejection, got ${_result}: ${_out}${_err}")
endif()
if(DIAGNOSTICS AND NOT _err MATCHES "control flow integrity check")
  message(FATAL_ERROR "Missing CFI diagnostic: ${_result}: ${_out}${_err}")
endif()
