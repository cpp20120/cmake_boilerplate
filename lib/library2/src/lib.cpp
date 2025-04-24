#include <print>

#include "../include/include.hpp"

namespace lib2 {
  void print_world() {
    std::print("Hello");
  }
    int sum_of_numbers(const int first_number,const int second_number) {
      return first_number + second_number;
    };
}  // namespace lib2