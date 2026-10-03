#include "include.hpp"

int main() {
  // Return codes keep the checks active in optimized builds with NDEBUG.
  if (SAMPLE_NAMESPACE::sum_of_numbers(23, 45) != 68) return 1;
  if (SAMPLE_NAMESPACE::sum_of_numbers(-23, 23) != 0) return 2;
  return 0;
}
