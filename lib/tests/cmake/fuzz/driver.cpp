#include <cstddef>
#include <cstdint>
int exercise(unsigned char);
extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size) {
  if (size) { volatile int result = exercise(data[0]); (void)result; }
  return 0;
}
