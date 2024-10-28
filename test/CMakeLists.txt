include(CTest)
enable_testing()
find_package(GTest CONFIG REQUIRED)
include(GoogleTest)

set(SOURCE_FILES test_main.cpp)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -fprofile-arcs -ftest-coverage")
# Test executable
add_executable(Tests ${SOURCE_FILES})

# Link with Google Test
target_link_libraries(Tests PRIVATE GTest::gtest GTest::gtest_main GTest::gmock GTest::gmock_main)
gtest_add_tests(TARGET Tests)
