add_library(lib
  lib.cpp 
)

target_include_directories(lib PUBLIC include)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE lib)
