#include <cstdlib>
import math;
import math.extra;
int main(int argc, char** argv) {
  return argc == 2 && twice(20) + correction() == std::atoi(argv[1]) ? 0 : 1;
}
