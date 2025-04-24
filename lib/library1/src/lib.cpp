#include "../include/include.hpp"

#include <print>

namespace lib1 {
    void print_hello() {
        std::print("Hello");
    };
    int sum_of_numbers(const int a,const  int b) {
      return a + b;
    }
}