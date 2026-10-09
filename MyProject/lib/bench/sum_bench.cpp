#include <library1.hpp>

#include <charconv>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <string_view>

int main(int argc, char** argv) {
  int count = 1000000;
  if (argc > 2) return 2;
  if (argc == 2) {
    const std::string_view arg(argv[1]);
    const auto [end, error] = std::from_chars(arg.data(), arg.data() + arg.size(), count);
    if (error != std::errc{} || end != arg.data() + arg.size() || count <= 0) return 2;
  }
  const auto start = std::chrono::steady_clock::now();
  std::uint64_t checksum = 0;
  for (int i = 0; i < count; ++i) {
    checksum += static_cast<unsigned>(lib1::sum_of_numbers(i & 1023, 1));
  }
  const auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(
      std::chrono::steady_clock::now() - start).count();
  std::cout << "iterations=" << count << " ns=" << ns << " checksum=" << checksum << '\n';
}
