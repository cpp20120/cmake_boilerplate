add_library(library2 lib.cpp)

target_include_directories(library2 PUBLIC include)
#target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE lib2)
