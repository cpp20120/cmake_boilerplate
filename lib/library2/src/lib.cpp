/** @file
 * @brief Implementation of the greeting and worker-thread arithmetic examples.
 */
#include "../include/include.hpp"

#include <cstdio>
#include <thread>

namespace lib2 {

void print_world() { std::printf("World"); }

int sum_of_numbers(const int first_number, const int second_number) {
  return first_number + second_number;
}

int sum_on_worker(const int first_number, const int second_number) {
  int result = 0;
  std::jthread worker([&result, first_number, second_number] {
    result = first_number + second_number;
  });
  worker.join();
  return result;
}

}  // namespace lib2
