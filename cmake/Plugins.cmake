include_guard(GLOBAL)
include(GenerateExportHeader)

# A plugin is a runtime extension artifact, never a link-time dependency of a
# host/application. Its business ABI belongs to the application/runtime or an
# explicit plugin host; the framework models membership and placement but does
# not invent a universal plugin callback ABI.
function(boilerplate_add_plugin target)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "" "APPLICATION;FOR" "SOURCES;LIBRARIES;INCLUDE_DIRS;POLICIES;POLICY_OPTIONS")
  if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES OR NOT ARG_SOURCES)
    message(FATAL_ERROR "boilerplate_add_plugin(${target}): SOURCES required; invalid arguments")
  endif()
  _boilerplate_validate_link_dependencies(${target} ${ARG_LIBRARIES})
  add_library(${target} MODULE ${ARG_SOURCES})
  boilerplate_set_artifact_role(${target} PLUGIN)
  target_link_libraries(${target} PRIVATE ${ARG_LIBRARIES})
  string(MAKE_C_IDENTIFIER "${target}" _prefix)
  string(TOUPPER "${_prefix}" _prefix)
  set(_generated "${CMAKE_CURRENT_BINARY_DIR}/generated/${target}")
  file(MAKE_DIRECTORY "${_generated}")
  set_target_properties(${target} PROPERTIES PREFIX "" POSITION_INDEPENDENT_CODE ON
    CXX_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN ON DEFINE_SYMBOL "${_prefix}_EXPORTS")
  generate_export_header(${target} BASE_NAME "${_prefix}"
    EXPORT_FILE_NAME "${_generated}/${target}_export.h" EXPORT_MACRO_NAME "${_prefix}_EXPORT")
  target_include_directories(${target} PRIVATE "${_generated}" ${ARG_INCLUDE_DIRS})
  set(_policy_args ${ARG_POLICY_OPTIONS})
  if(ARG_POLICIES)
    list(PREPEND _policy_args POLICIES ${ARG_POLICIES})
  endif()
  boilerplate_apply_optimization(${target} ${_policy_args})
  boilerplate_set_output_name(${target} "${target}")
  set(_plugin_runtimes)
  set(_plugin_libraries)
  foreach(_dependency IN LISTS ARG_LIBRARIES)
    if(TARGET ${_dependency})
      boilerplate_get_artifact_role(${_dependency} _role)
      _boilerplate_real_target(${_dependency} _real_dependency)
      get_target_property(_dependency_type ${_real_dependency} TYPE)
      if(_role STREQUAL "RUNTIME")
        list(APPEND _plugin_runtimes ${_dependency})
      elseif(_dependency_type STREQUAL "SHARED_LIBRARY")
        list(APPEND _plugin_libraries ${_dependency})
      endif()
    endif()
  endforeach()
  if(_plugin_runtimes)
    set_property(TARGET ${target} PROPERTY BOILERPLATE_PLUGIN_RUNTIMES "${_plugin_runtimes}")
  endif()
  if(_plugin_libraries)
    set_property(TARGET ${target} PROPERTY BOILERPLATE_PLUGIN_LIBRARIES "${_plugin_libraries}")
  endif()
  if(WIN32)
    _boilerplate_get_core_module_dir(_core_modules)
    add_custom_command(TARGET ${target} POST_BUILD
      COMMAND "${CMAKE_COMMAND}" "-DRUNTIME_FILES=$<TARGET_RUNTIME_DLLS:${target}>"
        "-DDESTINATION=$<TARGET_FILE_DIR:${target}>"
        -P "${_core_modules}/packaging/CopyRuntimeLibraries.cmake" VERBATIM)
  endif()
  boilerplate_get_target_setting(${target} CFI _cfi)
  boilerplate_get_target_setting(${target} CFI_DIAGNOSTICS _diagnostics)
  if(NOT _cfi STREQUAL "none" AND _diagnostics)
    message(FATAL_ERROR "Plugin ${target}: diagnostic CFI requires a host-owned UBSan runtime; use trap mode or configure a native MODULE target explicitly")
  endif()
  if(ARG_APPLICATION AND ARG_FOR)
    message(FATAL_ERROR "boilerplate_add_plugin(${target}): use APPLICATION or legacy FOR, not both")
  endif()
  set(_owner "${ARG_APPLICATION}")
  if(NOT _owner)
    set(_owner "${ARG_FOR}")
  endif()
  if(_owner)
    boilerplate_application_use_plugin(${_owner} ${target})
  endif()
endfunction()

# Typed composition edge: APPLICATION -> PLUGIN. This says that the plugin is in
# the application's extension set, not where it executes. With no explicit
# HOST -> PLUGIN edge it follows the application's hosts (normal in-process
# loading by application/runtime policy). An explicit plugin host overrides
# that default execution placement.
function(boilerplate_application_use_plugin application plugin)
  _boilerplate_require_artifact_role(${application} "APPLICATION" "boilerplate_application_use_plugin")
  _boilerplate_require_artifact_role(${plugin} "PLUGIN" "boilerplate_application_use_plugin")
  _boilerplate_append_target_property(${application} BOILERPLATE_APPLICATION_PLUGINS ${plugin})
  _boilerplate_append_target_property(${plugin} BOILERPLATE_PLUGIN_APPLICATIONS ${application})
  # Compatibility with the earlier ownership spelling.
  _boilerplate_append_target_property(${plugin} BOILERPLATE_OWNING_APPLICATIONS ${application})

  add_dependencies(${application} ${plugin})
endfunction()
