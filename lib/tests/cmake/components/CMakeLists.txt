cmake_minimum_required(VERSION 3.26)
project(ComponentWorkspaceFixture VERSION 1.0.0 LANGUAGES CXX)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES project-minimal diagnostics)

boilerplate_add_component(core SOURCE_DIR core FOLDER "fixture/core"
        DESCRIPTION "Reusable core component")
boilerplate_add_component(app SOURCE_DIR app FOLDER "fixture/app")
if(NOT COMPONENT_PARENT_SCOPE_SIGNAL STREQUAL "published-by-app")
  message(FATAL_ERROR "Component wrapper swallowed child PARENT_SCOPE publication")
endif()

boilerplate_list_components(_components)
foreach(_required IN ITEMS core app)
  if(NOT _required IN_LIST _components)
    message(FATAL_ERROR "Component '${_required}' was not registered: ${_components}")
  endif()
endforeach()

boilerplate_component_targets(core _core_targets)
if(NOT component_core_shared IN_LIST _core_targets AND NOT component_core_static IN_LIST _core_targets)
  message(FATAL_ERROR "Core component does not own its library target: ${_core_targets}")
endif()
boilerplate_component_targets(app _app_targets)
if(NOT component_app IN_LIST _app_targets)
  message(FATAL_ERROR "App component does not own component_app: ${_app_targets}")
endif()

get_target_property(_app_component component_app BOILERPLATE_COMPONENT)
get_target_property(_app_folder component_app FOLDER)
if(NOT _app_component STREQUAL "app" OR NOT _app_folder STREQUAL "fixture/app")
  message(FATAL_ERROR "Component target metadata is wrong: component=${_app_component}, folder=${_app_folder}")
endif()

# Raw CMake targets remain an escape hatch but can opt back into workspace-wide
# workflows explicitly without acquiring an artifact role or a custom wrapper.
add_library(raw_component_target STATIC EXCLUDE_FROM_ALL raw.cpp)
boilerplate_register_target(raw_component_target COMPONENT core)
get_target_property(_raw_component raw_component_target BOILERPLATE_COMPONENT)
if(NOT _raw_component STREQUAL "core")
  message(FATAL_ERROR "Raw target adoption failed")
endif()

boilerplate_finalize_project()
