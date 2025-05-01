if(NOT TARGET library2)
  message(FATAL_ERROR "Library2 not found!")
endif()

if(NOT TARGET GTest::GTest)
  find_package(GTest REQUIRED)
endif()

add_executable(lib2_test lib_test.cpp)
target_link_libraries(lib2_test PRIVATE library2 GTest::GTest GTest::Main)

include(GoogleTest)
gtest_discover_tests(lib2_test)
