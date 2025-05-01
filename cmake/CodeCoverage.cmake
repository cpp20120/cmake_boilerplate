# cmake/CodeCoverage.cmake
option(ENABLE_CODE_COVERAGE "Enable code coverage reporting" OFF)

if(ENABLE_CODE_COVERAGE)
  # Ищем инструменты coverage
  find_program(LLVM_COV_PATH llvm-cov)
  find_program(GCOV_PATH gcov)
  find_program(LCOV_PATH lcov)
  find_program(GENHTML_PATH genhtml)

  if(LLVM_COV_PATH)
    message(STATUS "Found llvm-cov: ${LLVM_COV_PATH}")
    set(COVERAGE_TOOL "llvm-cov")
  elseif(GCOV_PATH)
    message(STATUS "Found gcov: ${GCOV_PATH}")
    set(COVERAGE_TOOL "gcov")
  else()
    message(WARNING "Code coverage enabled but no coverage tool found (llvm-cov/gcov)")
    return()
  endif()

  # Настройка флагов компиляции
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang|GNU")
    add_compile_options(--coverage -fprofile-arcs -ftest-coverage)
    add_link_options(--coverage)
  endif()

  # Создаем каталог для отчетов
  set(COVERAGE_DIR "${CMAKE_BINARY_DIR}/coverage")
  file(MAKE_DIRECTORY ${COVERAGE_DIR})

  if(COVERAGE_TOOL STREQUAL "llvm-cov")
    # Для llvm-cov (профилирование + отчет в один шаг)
    add_custom_target(
      coverage
      COMMAND ${CMAKE_CTEST_COMMAND} --test-dir ${CMAKE_BINARY_DIR}
      COMMAND ${LLVM_COV_PATH} show -instr-profile=default.profdata -format=html -output-dir=${COVERAGE_DIR}/html
              ${CMAKE_BINARY_DIR}/bin/${PROJECT_NAME}
      COMMAND ${LLVM_COV_PATH} export -instr-profile=default.profdata ${CMAKE_BINARY_DIR}/bin/${PROJECT_NAME} >
              ${COVERAGE_DIR}/coverage.json
      WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
      COMMENT "Generating code coverage report using llvm-cov")
  else()
    # Для gcov + lcov
    if(LCOV_PATH AND GENHTML_PATH)
      add_custom_target(
        coverage
        # Очистка старых данных
        COMMAND ${LCOV_PATH} --directory . --zerocounters
        # Запуск тестов
        COMMAND ${CMAKE_CTEST_COMMAND} --test-dir ${CMAKE_BINARY_DIR}
        # Сбор данных
        COMMAND ${LCOV_PATH} --directory . --capture --output-file ${COVERAGE_DIR}/coverage.info
        # Очистка от системных файлов
        COMMAND ${LCOV_PATH} --remove ${COVERAGE_DIR}/coverage.info '/usr/*' '*/tests/*' --output-file
                ${COVERAGE_DIR}/filtered.info
        # Генерация HTML
        COMMAND ${GENHTML_PATH} ${COVERAGE_DIR}/filtered.info --output-directory ${COVERAGE_DIR}/html
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating code coverage report using gcov/lcov")
    else()
      message(WARNING "lcov/genhtml not found - cannot generate HTML reports")
    endif()
  endif()

  # Добавляем зависимость от тестов
  add_dependencies(coverage ${PROJECT_NAME}_tests)

  message(STATUS "Code coverage targets enabled. Use 'make coverage' to generate report.")
endif()
