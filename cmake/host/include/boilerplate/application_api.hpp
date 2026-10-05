#pragma once

#include <cstdint>

// Stable bootstrap ABI between a process host and an application image. Keep
// this boundary C-shaped: no STL, exceptions, allocator ownership or C++ class
// layout crosses it. Rich application/runtime APIs can be negotiated after
// bootstrap by the application itself.
struct BoilerplateApplicationApi {
  std::uint32_t version;
  std::uint32_t size;
  int (*run)(int argc, char** argv);
};

using BoilerplateApplicationQuery = const BoilerplateApplicationApi* (*)(
    std::uint32_t version, std::uint32_t size);

inline constexpr std::uint32_t boilerplate_application_abi_version = 1;
inline constexpr const char* boilerplate_application_query_symbol =
    "boilerplate_application_query";
