#include <gtest/gtest.h>

#include <iostream>
#include <library2.hpp>

TEST(SumOfNumbersTest2, PositiveNumbers) {
  std::cout << "SecondLib Tests\n";
  ASSERT_EQ(5, lib2::sum_of_numbers(2, 3));
  ASSERT_EQ(10, lib2::sum_of_numbers(5, 5));
  ASSERT_EQ(100, lib2::sum_of_numbers(50, 50));
}

TEST(SumOfNumbersTest2, NegativeNumbers) {
  ASSERT_EQ(-5, lib2::sum_of_numbers(-2, -3));
  ASSERT_EQ(-10, lib2::sum_of_numbers(-5, -5));
  ASSERT_EQ(-100, lib2::sum_of_numbers(-50, -50));
}

TEST(SumOfNumbersTest2, MixedNumbers) {
  ASSERT_EQ(1, lib2::sum_of_numbers(3, -2));
  ASSERT_EQ(-1, lib2::sum_of_numbers(-3, 2));
  ASSERT_EQ(0, lib2::sum_of_numbers(5, -5));
}

TEST(SumOfNumbersTest2, WorkerThread) {
  ASSERT_EQ(42, lib2::sum_on_worker(19, 23));
  ASSERT_EQ(-7, lib2::sum_on_worker(-10, 3));
}

TEST(SumOfNumbersTest2, Zero) {
  ASSERT_EQ(5, lib2::sum_of_numbers(5, 0));
  ASSERT_EQ(-5, lib2::sum_of_numbers(-5, 0));
  ASSERT_EQ(0, lib2::sum_of_numbers(0, 0));
}

int runTests(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}