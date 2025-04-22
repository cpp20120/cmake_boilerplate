#include <gtest/gtest.h>
#include "../include/include.hpp"

GTEST_TEST(FuncTest, PositiveNumbers) {
  ASSERT_EQ(proj::func(2, 3), 5);
}

GTEST_TEST(FuncTest, NegativeNumbers) {
  ASSERT_EQ(proj::func(-2, -3), -5);
}

GTEST_TEST(FuncTest, Zero) {
  ASSERT_EQ(proj::func(0, 5), 5);
  ASSERT_EQ(proj::func(5, 0), 5);
}

GTEST_TEST(FuncTest, Overflow) {
  ASSERT_EQ(proj::func(INT_MAX, 1), INT_MIN);
}
int main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}