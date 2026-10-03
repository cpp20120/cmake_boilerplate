#include <algorithm>
#include <vector>
#include <gtest/gtest.h>
#include <rapidcheck/gtest.h>

RC_GTEST_PROP(VectorProperties, reverseTwiceIsIdentity,
              (const std::vector<int>& values)) {
  auto twice = values;
  std::reverse(twice.begin(), twice.end());
  std::reverse(twice.begin(), twice.end());
  RC_ASSERT(twice == values);
}
