add_library(lib
  lib.cpp 
)

target_include_directories(lib PRIVATE include)

target_link_libraries(lib)