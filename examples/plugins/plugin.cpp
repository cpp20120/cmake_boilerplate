#include <api.hpp>
#include <example_plugin_export.h>

#ifndef EXAMPLE_PLUGIN_VERSION
#define EXAMPLE_PLUGIN_VERSION 1
#endif
#ifdef EXAMPLE_PLUGIN_DEPENDENCY
extern "C" int plugin_increment();
#endif

namespace {
std::int32_t step(std::int32_t state) {
#ifdef EXAMPLE_PLUGIN_DEPENDENCY
  return state + plugin_increment();
#else
  return state + 1;
#endif
}
const ExamplePluginApi api{EXAMPLE_PLUGIN_VERSION, sizeof(ExamplePluginApi), step};
}

extern "C" EXAMPLE_PLUGIN_EXPORT const ExamplePluginApi* example_plugin_query(
    std::uint32_t version, std::uint32_t size) {
  return version == api.version && size == api.size ? &api : nullptr;
}
