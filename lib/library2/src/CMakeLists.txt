add_library(lib2
  lib.cpp 
)

target_include_directories(lib2 PUBLIC include)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE lib2)
  