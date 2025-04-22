#include <gtest/gtest.h>
#include <iostream>
#include <sstream>
#include <string>
#include "../include/include.hpp"

class CoutCapture {
public:
  CoutCapture() : oldCout(std::cout.rdbuf()) {
    std::cout.rdbuf(ss.rdbuf());
  }

  ~CoutCapture() {
    std::cout.rdbuf(oldCout);
  }

  std::string getOutput() const {
    return ss.str();
  }

private:
  std::stringstream ss;
  std::streambuf* oldCout;
};

TEST(Lib2Test, PrintWorld) {
  CoutCapture capture;
  lib2::print_world();
  std::string output = capture.getOutput();
  EXPECT_EQ(output, "world");
}
