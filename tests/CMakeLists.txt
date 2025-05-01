option(BUILD_ALL_TESTS "Build all module tests automatically" ON)
enable_testing()

if(BUILD_TESTS AND BUILD_TESTING)
  if(NOT TARGET GTest::GTest)
    find_package(GTest REQUIRED)
  endif()

  add_executable(TEST_PROJECT_tests test_main.cpp)
  target_link_libraries(TEST_PROJECT_tests PRIVATE GTest::GTest GTest::Main)

  if(TARGET GTest::gtest)
    message(STATUS "Using GTest from root configuration")
  else()
    message(FATAL_ERROR "GTest not found but BUILD_TESTS is ON")
  endif()
endif()

add_custom_target(
  run_all_tests
  COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
  COMMENT "Running all tests"
  VERBATIM)

# Добавляем зависимости всех тестов
foreach(test_target IN ITEMS lib1_test lib2_test TEST_PROJECT_tests)
  if(TARGET ${test_target})
    add_dependencies(run_all_tests ${test_target})
  endif()
endforeach()
