add_library(lib1
  lib.cpp 
)

target_include_directories(lib1 PUBLIC include)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE lib1)
