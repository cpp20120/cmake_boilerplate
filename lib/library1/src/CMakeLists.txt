add_library(library1 lib.cpp)

target_include_directories(library1 PUBLIC include)
#target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE library1)
