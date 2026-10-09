cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "CHECK_BINARY is required")
endif()
function(run)
  execute_process(COMMAND ${ARGV} RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Failed: ${ARGV}\n${_out}\n${_err}")
  endif()
endfunction()
get_filename_component(_modules "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
set(_args)
if(CHECK_COMPILER)
  list(APPEND _args "-DCMAKE_CXX_COMPILER=${CHECK_COMPILER}")
endif()
if(NOT CHECK_GENERATOR)
  set(CHECK_GENERATOR Ninja)
endif()
set(_root "${CHECK_BINARY}/application-model")
file(REMOVE_RECURSE "${_root}")
set(_build "${_root}/build")
run("${CMAKE_COMMAND}" -S "${CMAKE_CURRENT_LIST_DIR}/application-model" -B "${_build}"
  -G "${CHECK_GENERATOR}" -DCMAKE_BUILD_TYPE=Release ${_args}
  "-DBOILERPLATE_MODULE_DIR=${_modules}")
run("${CMAKE_COMMAND}" --build "${_build}" --config Release --parallel 2)

set(_invalid_build "${_root}/invalid-link")
execute_process(COMMAND "${CMAKE_COMMAND}" -S "${CMAKE_CURRENT_LIST_DIR}/application-model"
  -B "${_invalid_build}" -G "${CHECK_GENERATOR}" -DCMAKE_BUILD_TYPE=Release ${_args}
  "-DBOILERPLATE_MODULE_DIR=${_modules}" -DAPPLICATION_MODEL_INVALID_LINK=ON
  RESULT_VARIABLE _invalid_result OUTPUT_VARIABLE _invalid_out ERROR_VARIABLE _invalid_err)
set(_invalid_text "${_invalid_out}${_invalid_err}")
string(FIND "${_invalid_text}" "APPLICATION artifact" _role_pos)
string(FIND "${_invalid_text}" "link-time library" _link_pos)
if(_invalid_result EQUAL 0 OR _role_pos EQUAL -1 OR _link_pos EQUAL -1)
  message(FATAL_ERROR
    "Expected semantic application-link rejection, got ${_invalid_result}: ${_invalid_text}")
endif()
include("${_build}/paths-Release.cmake")

if(NOT app_role STREQUAL "APPLICATION" OR NOT runtime_role STREQUAL "RUNTIME" OR
   NOT default_host_role STREQUAL "HOST" OR NOT app_type STREQUAL "MODULE_LIBRARY")
  message(FATAL_ERROR
    "Semantic roles/types are wrong: app=${app_role}/${app_type}, runtime=${runtime_role}, host=${default_host_role}")
endif()
if(NOT "sample_app_host" IN_LIST hosts OR NOT "sample_app_tools" IN_LIST hosts)
  message(FATAL_ERROR "Application did not retain both hosts: ${hosts}")
endif()
if(NOT "sample_app_host" IN_LIST inproc_hosts OR NOT "sample_app_tools" IN_LIST inproc_hosts)
  message(FATAL_ERROR "Implicit in-process plugin did not follow application hosts: ${inproc_hosts}")
endif()
list(LENGTH inproc_hosts _inproc_host_count)
if(NOT _inproc_host_count EQUAL 2)
  message(FATAL_ERROR "Implicit in-process plugin has unexpected hosts: ${inproc_hosts}")
endif()
if(NOT isolated_hosts STREQUAL "sample_plugin_host")
  message(FATAL_ERROR "Explicit plugin placement did not override co-hosting: ${isolated_hosts}")
endif()
foreach(_deployment_host IN ITEMS sample_app_host sample_app_tools sample_plugin_host)
  if(NOT _deployment_host IN_LIST deployment_hosts)
    message(FATAL_ERROR "Application deployment missed host ${_deployment_host}: ${deployment_hosts}")
  endif()
endforeach()

if(default_host_links MATCHES "(^|;)sample_app(;|$)")
  message(FATAL_ERROR "Generated host must load, not link, the application image: ${default_host_links}")
endif()

run("${default_host}" probe)
run("${tools_host}" probe)
run("${plugin_host}" "${plugin}")

set(_prefix "${_root}/prefix")
run("${CMAKE_COMMAND}" --install "${_build}" --config Release --prefix "${_prefix}" --component Runtime)
foreach(_required IN ITEMS
    "${_prefix}/bin/${default_host_name}"
    "${_prefix}/bin/${tools_host_name}"
    "${_prefix}/bin/${plugin_host_name}"
    "${_prefix}/${private_dir}/${app_module_name}"
    "${_prefix}/${private_dir}/${runtime_name}"
    "${_prefix}/${private_dir}/${plugin_runtime_name}"
    "${_prefix}/${plugin_dir}/${plugin_name}"
    "${_prefix}/${plugin_dir}/${inproc_plugin_name}"
    "${_prefix}/${resource_dir}/message.txt")
  if(NOT EXISTS "${_required}")
    message(FATAL_ERROR "Application deployment is missing: ${_required}")
  endif()
endforeach()

set(_relocated "${_root}/relocated")
file(RENAME "${_prefix}" "${_relocated}")
run("${CMAKE_COMMAND}" -E env --unset=LD_LIBRARY_PATH --unset=DYLD_LIBRARY_PATH
  "${_relocated}/bin/${default_host_name}" probe)
run("${CMAKE_COMMAND}" -E env --unset=LD_LIBRARY_PATH --unset=DYLD_LIBRARY_PATH
  "${_relocated}/bin/${tools_host_name}" probe)
run("${CMAKE_COMMAND}" -E env --unset=LD_LIBRARY_PATH --unset=DYLD_LIBRARY_PATH
  "${_relocated}/bin/${plugin_host_name}" "${_relocated}/${plugin_dir}/${plugin_name}")
message(STATUS "Application image, runtime, co-hosted/isolated plugins, multi-host graph and relocated private deployment passed (${CHECK_GENERATOR})")
