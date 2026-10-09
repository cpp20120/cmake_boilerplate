
/**
 * @file
 * @brief Sample application linking both example libraries.
 */
#include <project.hpp>
#include <library1.hpp>
#include <library2.hpp>


/**
 * @brief Print "HelloWorld" and exercise the sample arithmetic APIs.
 * @return Zero after the example calls complete successfully.
 */
int main() {
 proj::func(1, 2);
 lib1::print_hello();
 lib2::print_world();

  constexpr int first_number = 23;
  constexpr int second_number = 45;
  lib1::add_numbers(first_number, second_number);
  lib2::sum_of_numbers(first_number, second_number);
 lib2::sum_on_worker(first_number, second_number);
 return 0;
}
