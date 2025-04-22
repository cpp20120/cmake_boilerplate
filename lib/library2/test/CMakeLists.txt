cmake_minimum_required(VERSION 3.26)
project(Lib2Tests)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -fprofile-arcs -ftest-coverage")

# Ищем GTest
#find_package(GTest REQUIRED)
#include(GoogleTest)

#file(GLOB TEST_SOURCES "*.cpp")

#add_executable(lib_tests ${TEST_SOURCES})

#target_link_libraries(lib_tests PRIVATE 
#    lib1  
#    GTest::GTest 
#    GTest::Main
#)

#gtest_discover_tests(lib_tests)

#add_custom_target(run_lib_tests
#    COMMAND lib_tests
#    DEPENDS lib_tests
#    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
#    COMMENT "Running library tests..."
#)