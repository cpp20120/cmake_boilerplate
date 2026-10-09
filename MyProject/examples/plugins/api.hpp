#pragma once
#include <cstdint>

// The ABI uses fixed-width values and a C entry point. No STL, exceptions,
// allocator ownership or C++ class layout crosses the library boundary.
struct ExamplePluginApi {
  std::uint32_t version;
  std::uint32_t size;
  std::int32_t (*step)(std::int32_t state);
};
using ExamplePluginQuery = const ExamplePluginApi* (*)(std::uint32_t, std::uint32_t);
inline constexpr std::uint32_t example_plugin_version = 1;
