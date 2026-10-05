#include "gpu.hpp"
extern __device__ int device_value();
__global__ void policy_kernel(int* result) { *result = device_value(); }
int gpu_host_value() { return 42; }
