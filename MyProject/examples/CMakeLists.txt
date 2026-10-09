boilerplate_add_example(allocator_example
  SOURCES allocator.cpp
  SMOKE
  PGO
  LABELS allocator)
boilerplate_use_allocator(allocator_example)
add_subdirectory(plugins)
