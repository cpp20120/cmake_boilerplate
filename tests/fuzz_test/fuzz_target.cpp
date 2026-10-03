#include <cstddef>
#include <cstdint>
// Replace this bounded parser with the application's actual parsing/API entry.
extern "C" int LLVMFuzzerTestOneInput(const std::uint8_t* data, std::size_t size) {
  std::uint64_t sum = 0;
  for (std::size_t i = 0; i < size; ++i) sum += data[i];
  volatile std::uint64_t observed = sum;
  (void)observed;
  return 0;
}
