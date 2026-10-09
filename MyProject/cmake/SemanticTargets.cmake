include_guard(GLOBAL)

# Roles owned by the full execution layer. LINKABLE is an architectural
# permission, not a CMake TYPE: runtimes may be linked inside the process graph;
# applications, plugins and hosts may not masquerade as libraries.
boilerplate_register_artifact_role(RUNTIME LINKABLE)
boilerplate_register_artifact_role(APPLICATION)
boilerplate_register_artifact_role(PLUGIN)
boilerplate_register_artifact_role(HOST)

# Shared mechanics for semantic artifacts. Artifact meaning lives in the role
# graph; this helper only applies the ordinary target policy backend.
function(_boilerplate_apply_semantic_target_policy target)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "" "" "POLICIES;POLICY_OPTIONS")
  set(_policy_args)
  if(ARG_POLICIES)
    list(APPEND _policy_args POLICIES ${ARG_POLICIES})
  endif()
  if(ARG_POLICY_OPTIONS)
    list(APPEND _policy_args ${ARG_POLICY_OPTIONS})
  endif()
  boilerplate_apply_optimization(${target} ${_policy_args})
endfunction()

function(_boilerplate_get_core_module_dir out_var)
  get_property(_dir GLOBAL PROPERTY BOILERPLATE_CORE_MODULE_DIR)
  if(NOT _dir)
    message(FATAL_ERROR "Full boilerplate execution layer was not initialized through cmake/Boilerplate.cmake")
  endif()
  set(${out_var} "${_dir}" PARENT_SCOPE)
endfunction()
