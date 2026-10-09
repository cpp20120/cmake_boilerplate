extern __device__ int device_value();
__global__ void direct_kernel(int* result) { *result = device_value(); }
// This fixture links real device code but does not require a GPU at runtime.
int main() { return 0; }
