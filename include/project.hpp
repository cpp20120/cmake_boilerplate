/**
 * @file
 * @brief Header-only arithmetic used by the sample application.
 */
#ifndef PROJECT_ARITHMETIC_HPP
#define PROJECT_ARITHMETIC_HPP

/// @brief Helpers belonging to the sample application.
namespace proj {
/**
 * @brief Add two integers in the calling thread.
 * @param first_number First operand.
 * @param second_number Second operand.
 * @return The sum of the two operands.
 * @pre The mathematical sum must be representable as an int.
 * @note Overflow is not checked; signed integer overflow is undefined behavior.
 */
static int func(const int first_number, const int second_number) {
  return first_number + second_number;
}
}

#endif
