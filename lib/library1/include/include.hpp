#include <type_traits>
#ifndef LIB1_INCLUDE_HPP
#define LIB1_INCLUDE_HPP


namespace lib1 {

void print_hello();

/**
 *
 * @param first_number fist int number
 * @param second_number second int number
 * @return sum of both
 */
inline int add_numbers(const int first_number,const int second_number) { return first_number + second_number; }
/**
 *
 * @param first_number fist int number
 * @param second_number second int number
 * @return sum of both
 */
int sum_of_numbers(const int first_number,const int second_number);

template <typename T>
concept Arithmetic = std::is_arithmetic_v<T>;

template <Arithmetic T>
constexpr T add_numbers(const T first_number, const T second_number) {
  return first_number + second_number;
}

}  // namespace lib1

#endif  // LIB1_INCLUDE_HPP
