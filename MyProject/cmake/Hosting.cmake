include_guard(GLOBAL)
include(GNUInstallDirs)

# HOST is the process/lifecycle boundary. It is intentionally orthogonal to the
# thing being hosted: applications, plugin domains and future workload kinds all
# use the same execution artifact. A source-less host is a deferred generic host
# that is materialized when an application is attached.
function(boilerplate_add_host target)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "" "KIND;OUTPUT_NAME"
    "SOURCES;LIBRARIES;POLICIES;POLICY_OPTIONS")
  if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
    message(FATAL_ERROR "boilerplate_add_host(${target}): invalid arguments")
  endif()
  _boilerplate_validate_link_dependencies(${target} ${ARG_LIBRARIES})
  if(NOT ARG_KIND)
    set(ARG_KIND CONSOLE)
  endif()
  string(TOUPPER "${ARG_KIND}" ARG_KIND)
  if(NOT ARG_KIND MATCHES "^(CONSOLE|GUI|CUSTOM)$")
    message(FATAL_ERROR "boilerplate_add_host(${target}): KIND must be CONSOLE, GUI or CUSTOM")
  endif()

  add_executable(${target} ${ARG_SOURCES})
  boilerplate_set_artifact_role(${target} HOST)
  set_target_properties(${target} PROPERTIES
    BOILERPLATE_HOST_KIND "${ARG_KIND}")
  if(ARG_SOURCES)
    set_property(TARGET ${target} PROPERTY BOILERPLATE_HOST_CUSTOM_SOURCES TRUE)
  else()
    set_property(TARGET ${target} PROPERTY BOILERPLATE_HOST_CUSTOM_SOURCES FALSE)
  endif()
  if(WIN32 AND ARG_KIND STREQUAL "GUI")
    set_property(TARGET ${target} PROPERTY WIN32_EXECUTABLE TRUE)
  endif()

  target_link_libraries(${target} PRIVATE ${ARG_LIBRARIES})
  _boilerplate_apply_semantic_target_policy(${target}
    POLICIES ${ARG_POLICIES} POLICY_OPTIONS ${ARG_POLICY_OPTIONS})
  if(ARG_OUTPUT_NAME)
    boilerplate_set_output_name(${target} "${ARG_OUTPUT_NAME}")
  else()
    boilerplate_set_output_name(${target} "${target}")
  endif()
endfunction()

# Typed execution edge: HOST -> APPLICATION. Any number of hosts may point at the
# same application. Custom hosts may host multiple applications; the supplied
# generic loader intentionally handles exactly one application image.
#
# Plugins used by the application are not copied into BOILERPLATE_HOSTED_PLUGINS:
# APPLICATION -> PLUGIN is the extension/composition edge, while HOST -> PLUGIN
# is an explicit execution-placement edge. With no explicit plugin host, a
# plugin is effectively co-hosted with the application's hosts and is loaded by
# application/runtime policy rather than by the generic process host.
function(boilerplate_host_application host application)
  _boilerplate_require_artifact_role(${host} "HOST" "boilerplate_host_application")
  _boilerplate_require_artifact_role(${application} "APPLICATION" "boilerplate_host_application")

  _boilerplate_real_target(${host} _host)
  get_target_property(_custom ${_host} BOILERPLATE_HOST_CUSTOM_SOURCES)
  get_target_property(_materialized ${_host} BOILERPLATE_HOST_GENERIC_APPLICATION)
  if(NOT _custom)
    if(_materialized AND NOT _materialized STREQUAL application)
      message(FATAL_ERROR
        "Host ${host}: the framework generic host can host one application image; add SOURCES for a custom multi-application host")
    endif()
    if(NOT _materialized)
      target_sources(${_host} PRIVATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/host/ApplicationHost.cpp")
      target_include_directories(${_host} PRIVATE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/host/include")
      target_link_libraries(${_host} PRIVATE ${CMAKE_DL_LIBS})
      get_target_property(_kind ${_host} BOILERPLATE_HOST_KIND)
      if(WIN32 AND _kind STREQUAL "GUI")
        target_compile_definitions(${_host} PRIVATE BOILERPLATE_HOST_GUI=1)
        target_link_libraries(${_host} PRIVATE Shell32)
      endif()
      set(_config_dir "${CMAKE_CURRENT_BINARY_DIR}/generated/${host}/$<CONFIG>")
      file(GENERATE OUTPUT "${_config_dir}/boilerplate_host_config.hpp" CONTENT
"#pragma once\n#define BOILERPLATE_APPLICATION_NAME R\"bp(${application})bp\"\n#define BOILERPLATE_APPLICATION_MODULE_FILE R\"bp($<TARGET_FILE_NAME:${application}>)bp\"\n#define BOILERPLATE_APPLICATION_PRIVATE_DIR R\"bp(../${CMAKE_INSTALL_LIBDIR}/${application})bp\"\n#define BOILERPLATE_APPLICATION_BUILD_MODULE R\"bp($<TARGET_FILE:${application}>)bp\"\n")
      target_include_directories(${_host} PRIVATE "${_config_dir}")
      set_property(TARGET ${_host} PROPERTY BOILERPLATE_HOST_GENERIC_APPLICATION "${application}")
    endif()
  endif()

  _boilerplate_append_target_property(${_host} BOILERPLATE_HOSTED_APPLICATIONS ${application})
  _boilerplate_append_target_property(${application} BOILERPLATE_APPLICATION_HOSTS ${host})
  # Compatibility property for consumers that still expect a singular apphost.
  get_target_property(_hosted ${_host} BOILERPLATE_HOSTED_APPLICATIONS)
  list(LENGTH _hosted _hosted_count)
  if(_hosted_count EQUAL 1)
    set_property(TARGET ${_host} PROPERTY BOILERPLATE_HOST_APPLICATION "${application}")
  else()
    set_property(TARGET ${_host} PROPERTY BOILERPLATE_HOST_APPLICATION "")
  endif()

  add_dependencies(${_host} ${application})
endfunction()

# Typed execution edge: HOST -> PLUGIN. The framework does not invent a plugin
# ABI, therefore a plugin-only host must provide SOURCES implementing its loader.
# This still makes plugin hosting part of the same execution topology as apps.
function(boilerplate_host_plugin host plugin)
  _boilerplate_require_artifact_role(${host} "HOST" "boilerplate_host_plugin")
  _boilerplate_require_artifact_role(${plugin} "PLUGIN" "boilerplate_host_plugin")
  _boilerplate_real_target(${host} _host)
  get_target_property(_custom ${_host} BOILERPLATE_HOST_CUSTOM_SOURCES)
  get_target_property(_hosted_apps ${_host} BOILERPLATE_HOSTED_APPLICATIONS)
  if(NOT _custom AND NOT _hosted_apps)
    message(FATAL_ERROR
      "Host ${host}: plugin-only hosts require SOURCES because plugin ABI/loading policy belongs to the host contract")
  endif()
  _boilerplate_append_target_property(${_host} BOILERPLATE_HOSTED_PLUGINS ${plugin})
  _boilerplate_append_target_property(${plugin} BOILERPLATE_PLUGIN_HOSTS ${host})
  add_dependencies(${_host} ${plugin})
endfunction()

# Resolve execution placement for one application extension. Explicit
# HOST -> PLUGIN edges win. If there are none, the plugin follows the
# application's hosts (the normal in-process/co-hosted case). This keeps
# extension membership and process placement independent without requiring an
# extra declaration for the common case.
function(_boilerplate_get_effective_plugin_hosts application plugin out_var)
  _boilerplate_require_artifact_role(${application} "APPLICATION"
    "_boilerplate_get_effective_plugin_hosts")
  _boilerplate_require_artifact_role(${plugin} "PLUGIN"
    "_boilerplate_get_effective_plugin_hosts")

  get_target_property(_application_plugins ${application} BOILERPLATE_APPLICATION_PLUGINS)
  if(_application_plugins MATCHES "-NOTFOUND$")
    set(_application_plugins)
  endif()
  if(NOT plugin IN_LIST _application_plugins)
    message(FATAL_ERROR
      "Plugin ${plugin} is not an extension of application ${application}")
  endif()

  get_target_property(_explicit_hosts ${plugin} BOILERPLATE_PLUGIN_HOSTS)
  if(_explicit_hosts AND NOT _explicit_hosts MATCHES "-NOTFOUND$")
    set(_hosts ${_explicit_hosts})
  else()
    get_target_property(_hosts ${application} BOILERPLATE_APPLICATION_HOSTS)
    if(_hosts MATCHES "-NOTFOUND$")
      set(_hosts)
    endif()
  endif()
  if(_hosts)
    list(REMOVE_DUPLICATES _hosts)
  endif()
  set(${out_var} "${_hosts}" PARENT_SCOPE)
endfunction()

# Compatibility / happy-path sugar. The canonical model is add_host() followed
# by host_application(); keeping this spelling avoids breaking existing projects.
function(boilerplate_add_apphost target)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "" "APPLICATION;KIND;OUTPUT_NAME"
    "SOURCES;LIBRARIES;POLICIES;POLICY_OPTIONS")
  if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES OR NOT ARG_APPLICATION)
    message(FATAL_ERROR "boilerplate_add_apphost(${target}): APPLICATION required; invalid arguments")
  endif()
  set(_args)
  foreach(_one IN ITEMS KIND OUTPUT_NAME)
    if(ARG_${_one})
      list(APPEND _args ${_one} "${ARG_${_one}}")
    endif()
  endforeach()
  foreach(_many IN ITEMS SOURCES LIBRARIES POLICIES POLICY_OPTIONS)
    if(ARG_${_many})
      list(APPEND _args ${_many} ${ARG_${_many}})
    endif()
  endforeach()
  boilerplate_add_host(${target} ${_args})
  boilerplate_host_application(${target} ${ARG_APPLICATION})
endfunction()
