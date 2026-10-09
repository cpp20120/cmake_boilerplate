#include <flow.hpp>
#include <cstdio>

int main(int argc, char** argv) {
  if (argc != 2 || argv[1][0] < '0' || argv[1][0] > '2') return 2;
  std::fputs("CONTROL_FLOW_PROBE_READY\n", stderr);
  int (*volatile call)(int) = run_case;
  const int result = call(argv[1][0] - '0');
  std::fputs("CONTROL_FLOW_PROBE_FINISHED\n", stderr);
  return result;
}
