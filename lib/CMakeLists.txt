# Добавляем библиотеки
add_subdirectory(library1)
add_subdirectory(library2)

# Настройка тестов
option(BUILD_TESTS "Build tests" ON)
option(BUILD_ALL_TESTS "Build all tests automatically" ON)

if(BUILD_TESTS)
  enable_testing()
  find_package(GTest REQUIRED)

  if(BUILD_ALL_TESTS)
    # Добавляем тестовые поддиректории
    add_subdirectory(tests/lib1_test)
    add_subdirectory(tests/lib2_test)

    # Общая цель для запуска всех тестов
    add_custom_target(
      run_all_libs_tests
      COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
      COMMENT "Running all libraries tests"
      VERBATIM)

    # Добавляем зависимости если цели существуют
    foreach(test_target IN ITEMS lib1_test lib2_test)
      if(TARGET ${test_target})
        add_dependencies(run_all_libs_tests ${test_target})
      endif()
    endforeach()
  endif()
endif()
