#include "../include/include.hpp"
#include <limits>
int main() {
  if (proj::func(2, 3) != 5 || proj::func(-2, -3) != -5) return 1;
  if (proj::func(std::numeric_limits<int>::max(), 0) != std::numeric_limits<int>::max()) return 2;
  return 0;
}
