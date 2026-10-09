#include <cstdlib>
#include <iostream>

int main(int argc, char** argv) {
  int value = argc > 1 ? std::atoi(argv[1]) : 0;
  std::cout << "{\"status\":\"ok\",\"value\":" << value
            << ",\"checksum\":42}\n";
  return 0;
}
