/**
 * @file
 * @brief Public API of the dependency-free example library.
 */
#include <library1_export.h>
#include <type_traits>
#ifndef LIB1_INCLUDE_HPP
#define LIB1_INCLUDE_HPP

/// @brief Greeting and arithmetic examples without external dependencies.
namespace lib1 {

/**
 * @brief Write "Hello" to standard output without a trailing newline.
 * @note Output errors are not reported to the caller.
 */
LIBRARY1_EXPORT void print_hello();

/**
 * @brief Add two integers inline.
 * @param first_number First operand.
 * @param second_number Second operand.
 * @return The sum of the two operands.
 * @pre The mathematical sum must be representable as an int.
 * @note Overflow is not checked.
 */
inline int add_numbers(const int first_number,const int second_number) { return first_number + second_number; }
/**
 * @brief Add two integers through the compiled library API.
 * @param first_number First operand.
 * @param second_number Second operand.
 * @return The sum of the two operands.
 * @pre The mathematical sum must be representable as an int.
 * @note Overflow is not checked.
 */
LIBRARY1_EXPORT int sum_of_numbers(const int first_number,const int second_number);

/**
 * @brief Add two values of the same arithmetic type.
 * @tparam T An arithmetic type accepted by std::is_arithmetic_v.
 * @param first_number First operand.
 * @param second_number Second operand.
 * @return The result of built-in addition, converted to T.
 * @pre For signed integer arithmetic, the addition must not overflow its
 *      promoted operand type.
 * @note Integral promotions, conversion to T and floating-point rounding follow
 *       the normal C++ arithmetic rules. No overflow or precision checks occur.
 * @note This overload can be evaluated at compile time. Specify the template
 *       argument explicitly to select it for int, e.g. add_numbers<int>(2, 3).
 */
template <typename T, std::enable_if_t<std::is_arithmetic_v<T>, int> = 0>
constexpr T add_numbers(const T first_number, const T second_number) {
  return first_number + second_number;
}

}  // namespace lib1

#endif  // LIB1_INCLUDE_HPP
