#include <library2.hpp>

int main() {
  if (lib2::sum_of_numbers(20, 22) != 42) return 1;
  if (lib2::sum_on_worker(20, 22) != 42) return 2;
  return 0;
}
