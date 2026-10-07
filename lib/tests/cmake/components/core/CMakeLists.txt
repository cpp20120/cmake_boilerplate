cmake_minimum_required(VERSION 3.26)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  project(ComponentCoreStandalone VERSION 1.0.0 LANGUAGES CXX)
  include("${TOOLKIT_DIR}/Boilerplate.cmake")
  boilerplate_project(CAPABILITIES project-minimal diagnostics)
  boilerplate_component(core FOLDER "fixture/core"
    DESCRIPTION "Reusable core component")
endif()

boilerplate_add_library(component_core
  SOURCES core.cpp
  INCLUDE_DIR include
  POLICIES minimal)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  boilerplate_finalize_project()
endif()
