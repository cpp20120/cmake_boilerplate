#include <library1.hpp>
#include <library2.hpp>

int main() {
  // Exercise compiled symbols (including the transitive Threads dependency).
  // Explicit checks remain active in Release builds.
  if (lib1::sum_of_numbers(19, 23) != 42 ||
      lib2::sum_of_numbers(20, 22) != 42 ||
      lib2::sum_on_worker(21, 21) != 42) {
    return 1;
  }
  lib1::print_hello();
  lib2::print_world();
  return 0;
}
