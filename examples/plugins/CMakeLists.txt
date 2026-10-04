boilerplate_add_plugin(example_plugin SOURCES plugin.cpp POLICIES minimal)
boilerplate_add_executable(plugin_host SOURCES host.cpp POLICIES minimal
  LIBRARIES ${CMAKE_DL_LIBS})
add_dependencies(plugin_host example_plugin)
boilerplate_register_check(plugin_reload plugin_host
  ARGS "$<TARGET_FILE:example_plugin>" LABELS "example;plugin")
boilerplate_install_application(plugin_host PLUGINS example_plugin RESOURCE_DIRS resources)
