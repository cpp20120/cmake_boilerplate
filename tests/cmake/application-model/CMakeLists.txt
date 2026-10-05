cmake_minimum_required(VERSION 3.26)
project(ApplicationModelFixture LANGUAGES CXX)
include("${BOILERPLATE_MODULE_DIR}/Boilerplate.cmake")
set(BOILERPLATE_COMPILER_CACHE none CACHE STRING "" FORCE)
set(BOILERPLATE_INSTALL ON CACHE BOOL "" FORCE)
boilerplate_project(CAPABILITIES project-minimal)

boilerplate_add_runtime(sample_runtime
  SOURCES runtime.cpp
  INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
  POLICIES minimal)

boilerplate_add_runtime(sample_plugin_runtime
  SOURCES plugin_runtime.cpp
  INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
  POLICIES minimal)

boilerplate_add_application(sample_app
  SOURCES app.cpp
  RUNTIMES sample_runtime
  RESOURCE_DIRS resources
  POLICIES minimal)

option(APPLICATION_MODEL_INVALID_LINK "Exercise semantic link rejection" OFF)
if(APPLICATION_MODEL_INVALID_LINK)
  boilerplate_add_executable(invalid_consumer
    SOURCES invalid.cpp
    LIBRARIES sample_app
    POLICIES minimal)
endif()

boilerplate_add_host(sample_app_tools
  KIND CONSOLE
  POLICIES minimal)
boilerplate_host_application(sample_app_tools sample_app)

boilerplate_add_plugin(sample_plugin
  APPLICATION sample_app
  SOURCES plugin.cpp
  LIBRARIES sample_plugin_runtime
  POLICIES minimal)

boilerplate_add_plugin(sample_inproc_plugin
  APPLICATION sample_app
  SOURCES inproc_plugin.cpp
  POLICIES minimal)

boilerplate_add_host(sample_plugin_host
  SOURCES plugin_host.cpp
  LIBRARIES ${CMAKE_DL_LIBS}
  POLICIES minimal)
boilerplate_host_plugin(sample_plugin_host sample_plugin)

_boilerplate_get_effective_plugin_hosts(sample_app sample_inproc_plugin _inproc_hosts)
_boilerplate_get_effective_plugin_hosts(sample_app sample_plugin _isolated_hosts)

boilerplate_install_application(sample_app NO_RUNTIME_DEPENDENCIES)

file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/paths-$<CONFIG>.cmake" CONTENT
"set(default_host [==[$<TARGET_FILE:sample_app_host>]==])\nset(tools_host [==[$<TARGET_FILE:sample_app_tools>]==])\nset(app_module [==[$<TARGET_FILE:sample_app>]==])\nset(runtime [==[$<TARGET_FILE:sample_runtime>]==])\nset(plugin [==[$<TARGET_FILE:sample_plugin>]==])\nset(plugin_host [==[$<TARGET_FILE:sample_plugin_host>]==])\nset(app_role [==[$<TARGET_PROPERTY:sample_app,BOILERPLATE_ARTIFACT_ROLE>]==])\nset(hosts [==[$<TARGET_PROPERTY:sample_app,BOILERPLATE_APPLICATION_HOSTS>]==])\nset(deployment_hosts [==[$<TARGET_PROPERTY:sample_app,BOILERPLATE_APPLICATION_DEPLOYMENT_HOSTS>]==])\nset(inproc_hosts [==[${_inproc_hosts}]==])\nset(isolated_hosts [==[${_isolated_hosts}]==])\nset(private_dir [==[$<TARGET_PROPERTY:sample_app,BOILERPLATE_INSTALL_PRIVATE_DIR>]==])\nset(plugin_dir [==[$<TARGET_PROPERTY:sample_app,BOILERPLATE_INSTALL_PLUGIN_DIR>]==])\nset(resource_dir [==[$<TARGET_PROPERTY:sample_app,BOILERPLATE_INSTALL_RESOURCE_DIR>]==])\nset(default_host_name [==[$<TARGET_FILE_NAME:sample_app_host>]==])\nset(tools_host_name [==[$<TARGET_FILE_NAME:sample_app_tools>]==])\nset(plugin_host_name [==[$<TARGET_FILE_NAME:sample_plugin_host>]==])\nset(app_module_name [==[$<TARGET_FILE_NAME:sample_app>]==])\nset(runtime_name [==[$<TARGET_FILE_NAME:sample_runtime>]==])\nset(plugin_runtime_name [==[$<TARGET_FILE_NAME:sample_plugin_runtime>]==])\nset(plugin_name [==[$<TARGET_FILE_NAME:sample_plugin>]==])\nset(inproc_plugin_name [==[$<TARGET_FILE_NAME:sample_inproc_plugin>]==])\nset(app_type [==[$<TARGET_PROPERTY:sample_app,TYPE>]==])\nset(runtime_role [==[$<TARGET_PROPERTY:sample_runtime,BOILERPLATE_ARTIFACT_ROLE>]==])\nset(default_host_role [==[$<TARGET_PROPERTY:sample_app_host,BOILERPLATE_ARTIFACT_ROLE>]==])\nset(default_host_links [==[$<TARGET_PROPERTY:sample_app_host,LINK_LIBRARIES>]==])\n")
boilerplate_finalize_project()
