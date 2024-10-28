#include "../include/include.hpp"
#include "../lib/include/include.hpp"

#include <print>

auto main() -> int {
  lib::print_hello();
  auto a = proj::func(2, 3);
  std::print("{}", a);
}
