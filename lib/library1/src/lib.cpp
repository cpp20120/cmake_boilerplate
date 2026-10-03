/** @file
 * @brief Implementation of the dependency-free example library.
 */
#include "../include/include.hpp"

#include <cstdio>

namespace lib1 {
    void print_hello() {
        std::printf("Hello");
    };
    int sum_of_numbers(const int first_number, const int second_number) {
      return first_number + second_number;
    }
}
