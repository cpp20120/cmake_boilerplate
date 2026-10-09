#include <algorithm>
#include <vector>
#include <fuzztest/fuzztest.h>
#include <gtest/gtest.h>

void ReverseTwice(std::vector<int> values) {
  const auto original = values;
  std::reverse(values.begin(), values.end());
  std::reverse(values.begin(), values.end());
  EXPECT_EQ(values, original);
}
FUZZ_TEST(BoilerplateFuzzTest, ReverseTwice);
