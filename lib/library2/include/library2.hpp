/**
 * @file
 * @brief Public API of the example library with a Threads dependency.
 */
#ifndef LIB2_INCLUDE_HPP
#define LIB2_INCLUDE_HPP

#include <library2_export.h>

/// @brief Greeting, arithmetic and synchronous worker-thread examples.
namespace lib2 {

/**
 * @brief Write "World" to standard output without a trailing newline.
 * @note Output errors are not reported to the caller.
 */
LIBRARY2_EXPORT void print_world();

/**
 * @brief Add two integers inline in the calling thread.
 * @param first_number First operand.
 * @param second_number Second operand.
 * @return The sum of the two operands.
 * @pre The mathematical sum must be representable as an int.
 * @note Overflow is not checked.
 */
inline int add_numbers(const int first_number, const int second_number) {
  return first_number + second_number;
}

/**
 * @brief Add two integers through the compiled library API.
 * @param first_number First operand.
 * @param second_number Second operand.
 * @return The sum of the two operands.
 * @pre The mathematical sum must be representable as an int.
 * @note Overflow is not checked.
 */
LIBRARY2_EXPORT int sum_of_numbers(int first_number, int second_number);

/**
 * @brief Add two integers on a new worker thread and wait for it to finish.
 * @param first_number First operand, copied into the worker.
 * @param second_number Second operand, copied into the worker.
 * @return The sum after the worker has been joined.
 * @pre The mathematical sum must be representable as an int.
 * @throws std::system_error If thread creation or joining fails.
 * @note This call blocks and creates a new std::jthread for each invocation.
 *       It demonstrates the library's public Threads dependency; it is not
 *       intended to accelerate integer addition. Overflow is not checked.
 */
LIBRARY2_EXPORT int sum_on_worker(int first_number, int second_number);

}  // namespace lib2

#endif  // LIB2_INCLUDE_HPP
