if(NOT TARGET library1)
  message(FATAL_ERROR "Library1 not found!")
endif()

if(NOT TARGET GTest::GTest)
  find_package(GTest REQUIRED)
endif()

add_executable(lib1_test lib_test.cpp)
target_link_libraries(lib1_test PRIVATE library1 GTest::GTest GTest::Main)

include(GoogleTest)
gtest_discover_tests(lib1_test)
