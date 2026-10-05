include_guard(GLOBAL)
include(GenerateExportHeader)

# A runtime is a private, linkable process component. It is deliberately not a
# package-exported library: use boilerplate_add_library() for consumer-facing
# libraries. Runtime modules are deployment artifacts owned by applications.
function(boilerplate_add_runtime target)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "" "APPLICATION;FOR"
    "SOURCES;RUNTIMES;LIBRARIES;INCLUDE_DIRS;POLICIES;POLICY_OPTIONS")
  if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES OR NOT ARG_SOURCES)
    message(FATAL_ERROR "boilerplate_add_runtime(${target}): SOURCES required; invalid arguments")
  endif()
  _boilerplate_validate_link_dependencies(${target} ${ARG_LIBRARIES} ${ARG_RUNTIMES})
  foreach(_runtime IN LISTS ARG_RUNTIMES)
    _boilerplate_require_artifact_role(${_runtime} "RUNTIME" "Runtime ${target} RUNTIMES")
  endforeach()
  foreach(_library IN LISTS ARG_LIBRARIES)
    if(TARGET ${_library})
      boilerplate_get_artifact_role(${_library} _library_role)
      if(_library_role STREQUAL "RUNTIME")
        message(FATAL_ERROR
          "Runtime ${target}: runtime ${_library} must be declared in RUNTIMES, not LIBRARIES")
      endif()
    endif()
  endforeach()
  add_library(${target} SHARED ${ARG_SOURCES})
  boilerplate_set_artifact_role(${target} RUNTIME)

  string(MAKE_C_IDENTIFIER "${target}" _prefix)
  string(TOUPPER "${_prefix}" _prefix)
  set(_generated "${CMAKE_CURRENT_BINARY_DIR}/generated/${target}")
  file(MAKE_DIRECTORY "${_generated}")
  set_target_properties(${target} PROPERTIES
    PREFIX "" POSITION_INDEPENDENT_CODE ON
    CXX_EXTENSIONS OFF CXX_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN ON
    DEFINE_SYMBOL "${_prefix}_EXPORTS")
  generate_export_header(${target} BASE_NAME "${_prefix}"
    EXPORT_FILE_NAME "${_generated}/${target}_export.h"
    EXPORT_MACRO_NAME "${_prefix}_EXPORT")
  target_include_directories(${target} PUBLIC "${_generated}" ${ARG_INCLUDE_DIRS})
  target_link_libraries(${target} PRIVATE ${ARG_RUNTIMES} ${ARG_LIBRARIES})
  _boilerplate_apply_semantic_target_policy(${target}
    POLICIES ${ARG_POLICIES} POLICY_OPTIONS ${ARG_POLICY_OPTIONS})
  boilerplate_set_output_name(${target} "${target}")

  # Remember owned runtime-to-runtime edges for deployment closure.
  if(ARG_RUNTIMES)
    set_property(TARGET ${target} PROPERTY BOILERPLATE_RUNTIME_DEPENDENCIES "${ARG_RUNTIMES}")
  endif()
  set(_runtime_libraries)
  foreach(_dependency IN LISTS ARG_LIBRARIES)
    if(TARGET ${_dependency})
      _boilerplate_real_target(${_dependency} _real_dependency)
      get_target_property(_dependency_type ${_real_dependency} TYPE)
      if(_dependency_type STREQUAL "SHARED_LIBRARY")
        list(APPEND _runtime_libraries ${_dependency})
      endif()
    endif()
  endforeach()
  if(_runtime_libraries)
    set_property(TARGET ${target} PROPERTY BOILERPLATE_RUNTIME_LIBRARIES "${_runtime_libraries}")
  endif()

  if(ARG_APPLICATION AND ARG_FOR)
    message(FATAL_ERROR "boilerplate_add_runtime(${target}): use APPLICATION or legacy FOR, not both")
  endif()
  set(_owner "${ARG_APPLICATION}")
  if(NOT _owner)
    set(_owner "${ARG_FOR}")
  endif()
  if(_owner)
    _boilerplate_require_artifact_role(${_owner} "APPLICATION" "boilerplate_add_runtime(${target}) APPLICATION")
    _boilerplate_append_target_property(${_owner} BOILERPLATE_APPLICATION_RUNTIMES ${target})
    _boilerplate_append_target_property(${target} BOILERPLATE_OWNING_APPLICATIONS ${_owner})
    add_dependencies(${_owner} ${target})
  endif()
endfunction()

