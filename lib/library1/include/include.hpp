#ifndef LIB1_INCLUDE_HPP
#define LIB1_INCLUDE_HPP

#include <print>

namespace lib1 {

void print_hello();
inline void add_numbers(const int a,const int b) { std::print("Sum: {}", a + b); }

}  // namespace lib1

#endif  // LIB1_INCLUDE_HPP
