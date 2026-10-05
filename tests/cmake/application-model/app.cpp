#include "runtime.hpp"
#include <fstream>
#include <string>
int boilerplate_application_main(int argc, char** argv) {
  if (sample_runtime_value() != 42) return 10;
  if (argc >= 2 && std::string(argv[1]) == "probe") return 0;
  return 0;
}
