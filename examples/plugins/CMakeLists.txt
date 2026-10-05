boilerplate_add_plugin(example_plugin SOURCES plugin.cpp POLICIES minimal)
boilerplate_add_host(plugin_host SOURCES host.cpp POLICIES minimal
  LIBRARIES ${CMAKE_DL_LIBS})
boilerplate_host_plugin(plugin_host example_plugin)
boilerplate_register_check(plugin_reload plugin_host
  ARGS "$<TARGET_FILE:example_plugin>" LABELS "example;plugin")
boilerplate_install_host(plugin_host RESOURCE_DIRS resources NO_RUNTIME_DEPENDENCIES)
