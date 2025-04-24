
#include "../include/include.hpp"
#include "../lib/library1/include/include.hpp"
#include "../lib/library2/include/include.hpp"


int main() {
 proj::func(1, 2);
 lib1::print_hello();
 lib2::print_world();

  constexpr int first_number = 23;
  constexpr int second_number = 45;
  lib1::add_numbers(first_number, second_number);
  lib2::sum_of_numbers(first_number, second_number);
 return 0;
}