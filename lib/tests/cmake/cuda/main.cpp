#include <gpu.hpp>
int main() { return gpu_host_value() == 42 && cpu_host_value() == 42 ? 0 : 1; }
