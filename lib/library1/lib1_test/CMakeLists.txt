# lib/lib1/test/CMakeLists.txt
option(BUILD_TESTS "Build tests" ON)

if(NOT BUILD_ALL_TESTS AND NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    return()
endif()

if(NOT TARGET GTest::gtest)
    find_package(GTest REQUIRED CONFIG)
endif()

if(NOT COMMAND gtest_discover_tests)
    function(gtest_discover_tests TARGET)
        if(NOT TARGET ${TARGET})
            message(FATAL_ERROR "Cannot find target: ${TARGET}")
        endif()

        get_target_property(TEST_EXECUTABLE ${TARGET} LOCATION)
        if(NOT TEST_EXECUTABLE)
            get_target_property(TEST_EXECUTABLE ${TARGET} RUNTIME_OUTPUT_DIRECTORY)
            if(TEST_EXECUTABLE)
                set(TEST_EXECUTABLE "${TEST_EXECUTABLE}/${TARGET}")
            else()
                set(TEST_EXECUTABLE "$<TARGET_FILE:${TARGET}>")
            endif()
        endif()

        add_custom_target(${TARGET}_discover_tests ALL
            COMMAND ${TEST_EXECUTABLE} --gtest_list_tests
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            COMMENT "Discovering tests for ${TARGET}"
            VERBATIM
        )

        add_test(NAME ${TARGET}
            COMMAND ${TEST_EXECUTABLE}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        )
    endfunction()
endif()

# Макрос для быстрой сборки теста
function(add_module_test TEST_TARGET_NAME TEST_SOURCES)
    # Check if target already exists in global scope
    if(TARGET ${TEST_TARGET_NAME})
        message(WARNING "Target ${TEST_TARGET_NAME} already exists, skipping")
        return()
    endif()

    add_executable(${TEST_TARGET_NAME} ${TEST_SOURCES})

    target_link_libraries(${TEST_TARGET_NAME} PRIVATE
            library1
            GTest::gmock
            GTest::gtest
            GTest::gtest_main
    )

    include(GoogleTest)
    gtest_discover_tests(${TEST_TARGET_NAME})
endfunction()

add_module_test(library1_tests lib_test.cpp)
