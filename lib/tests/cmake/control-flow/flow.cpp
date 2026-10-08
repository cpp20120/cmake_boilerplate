#include <flow.hpp>

namespace {
int correct(int value) { return value; }
long wrong_signature(long value) { return value; }

struct Base {
  virtual ~Base() = default;
  virtual int value() const = 0;
};
struct Good final : Base {
  int value() const override { return 42; }
};
struct Unrelated {
  virtual ~Unrelated() = default;
  virtual int value() const { return 42; }
};
}  // namespace

int run_case(int which) {
  using Callback = int (*)(int);
  Callback volatile callback = which == 1
      ? reinterpret_cast<Callback>(&wrong_signature) : &correct;
  const int result = callback(42);
  Good good;
  Unrelated unrelated;
  Base* volatile object = which == 2 ? reinterpret_cast<Base*>(&unrelated) : &good;
  return result == 42 && object->value() == 42 ? 0 : 1;
}
