include_guard(DIRECTORY)

# Example-local policy pack.  It deliberately lives with library1 rather than
# in the reusable framework to prove that consumers can extend the policy
# vocabulary without modifying Boilerplate.cmake.
boilerplate_define_policy(example-library1
  INHERITS minimal werror)
boilerplate_define_policy(example-library1-shared
  INHERITS hardened)
boilerplate_define_policy(example-library1-static
  INHERITS unity)
