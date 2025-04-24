#include <gtest/gtest.h>

#include <iostream>
#include <string>

#include "../../library1/include/include.hpp"


TEST(SumOfNumbersTest, PositiveNumbers) {
  ASSERT_EQ(5, lib1::sum_of_numbers(2, 3));
  ASSERT_EQ(10, lib1::sum_of_numbers(5, 5));
  ASSERT_EQ(100, lib1::sum_of_numbers(50, 50));
}

TEST(SumOfNumbersTest, NegativeNumbers) {
  ASSERT_EQ(-5, lib1::sum_of_numbers(-2, -3));
  ASSERT_EQ(-10, lib1::sum_of_numbers(-5, -5));
  ASSERT_EQ(-100, lib1::sum_of_numbers(-50, -50));
}

TEST(SumOfNumbersTest, MixedNumbers) {
  ASSERT_EQ(1, lib1::sum_of_numbers(3, -2));
  ASSERT_EQ(-1, lib1::sum_of_numbers(-3, 2));
  ASSERT_EQ(0, lib1::sum_of_numbers(5, -5));
}

TEST(SumOfNumbersTest, Zero) {
  ASSERT_EQ(5, lib1::sum_of_numbers(5, 0));
  ASSERT_EQ(-5, lib1::sum_of_numbers(-5, 0));
  ASSERT_EQ(0, lib1::sum_of_numbers(0, 0));
}

int runTests(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}