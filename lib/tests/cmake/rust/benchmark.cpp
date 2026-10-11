#include <cstdlib>
#include <iostream>

int main(int argc, char** argv) {
  const int items = argc > 1 ? std::atoi(argv[1]) : 4;
  std::cout << "{\"status\":\"ok\",\"items\":" << items
            << ",\"checksum\":" << items * (items + 1) << "}\n";
}
