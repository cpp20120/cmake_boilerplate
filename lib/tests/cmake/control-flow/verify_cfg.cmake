execute_process(COMMAND "${DUMPBIN}" /headers /loadconfig "${BINARY}"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(NOT _result EQUAL 0 OR NOT _out MATCHES "CF Instrumented" OR NOT _out MATCHES "FID table present")
  message(FATAL_ERROR "CFG metadata missing from ${BINARY}: ${_out}${_err}")
endif()
