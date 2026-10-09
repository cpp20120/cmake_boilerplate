#pragma once
#include <string_view>

namespace boilerplate::build_info {
inline constexpr std::string_view project = "TEST_PROJECT";
inline constexpr std::string_view version = "1.0.0";
inline constexpr std::string_view revision = "ea82310aea568161e8159fd0e086171c6e877370";
inline constexpr std::string_view compiler = "Clang 22.1.8";
inline constexpr bool dirty = true;
}
