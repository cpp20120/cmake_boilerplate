#include <iostream>
#include <string_view>

int main(int argc, char** argv) {
  if (argc > 1 && std::string_view(argv[1]) == "fail") {
    std::cerr << "intentional dashboard failure\n";
    return 2;
  }
  std::cout << "dashboard fixture passed\n";
  return 0;
}
