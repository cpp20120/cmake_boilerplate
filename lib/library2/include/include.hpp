#ifndef LIB2_INCLUDE_HPP
#define LIB2_INCLUDE_HPP

namespace lib2 {

void print_world();
/**
 * @param first_number fist int number
 * @param second_number second int number
 * @return sum of both
 */
inline int add_numbers(const int first_number,const int second_number) { return first_number + second_number; }
/**
 * @param first_number fist int number
 * @param second_number second int number
 * @return sum of both
 */
int sum_of_numbers(const int first_number,const int second_number);

}  // namespace lib2

#endif  // LIB2_INCLUDE_HPP
