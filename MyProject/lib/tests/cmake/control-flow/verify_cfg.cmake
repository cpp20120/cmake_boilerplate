execute_process(
  COMMAND "${DUMPBIN}" /headers /loadconfig "${BINARY}"
  RESULT_VARIABLE _result
  OUTPUT_VARIABLE _out
  ERROR_VARIABLE _err
)

string(TOLOWER "${_out}" _out_lower)

if(
  NOT _result EQUAL 0
  OR NOT _out_lower MATCHES "cf instrumented"
  OR NOT _out_lower MATCHES "fid table present"
)
  message(FATAL_ERROR "CFG metadata missing from ${BINARY}: ${_out}${_err}")
endif()