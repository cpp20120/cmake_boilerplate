/**#pragma once

#include <gtest/gtest.h>
#include <print>
#include "../include/include.hpp"

// write tests for lib1 using google test
TEST(Lib1Test, PrintHello) {
  testing::internal::CaptureStdout();
  lib1::print_hello();
  std::string output = testing::internal::GetCapturedStdout();
  EXPECT_EQ(output, "Hello");
}
    */
