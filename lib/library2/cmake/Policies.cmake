include_guard(DIRECTORY)

# A different local composition from library1.  The two example libraries are
# intentional regression fixtures for independent consumer policy packs.
boilerplate_define_policy(example-library2
  INHERITS minimal frame-pointers)
boilerplate_define_policy(example-library2-shared
  INHERITS hardened)
boilerplate_define_policy(example-library2-static
  INHERITS reproducible)
