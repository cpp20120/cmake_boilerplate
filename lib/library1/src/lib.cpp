#include "../include/include.hpp"

#include <print>

namespace lib1 {
    void print_hello() {
        std::print("Hello");
    };
    int sum_of_numbers(const int first_number, const int second_number) {
      return first_number + second_number;
    }
}