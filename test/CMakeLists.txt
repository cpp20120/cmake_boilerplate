find_package(GTest CONFIG REQUIRED)
include(GoogleTest)

set(SOURCE_FILES test_main.cpp)

# Test executable
add_executable(Tests ${SOURCE_FILES})

# Link with Google Test
target_link_libraries(Tests PRIVATE GTest::GTest GTest::MAIN GTest::gmock GTest::gmock_main)
gtest_add_tests(TARGET Tests)
