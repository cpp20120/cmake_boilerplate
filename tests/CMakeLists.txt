if(BUILD_TESTS AND BUILD_TESTING)
    # GTest already found in root CMakeLists.txt, just use it
    if(TARGET GTest::gtest)
        message(STATUS "Using GTest from root configuration")
    else()
        message(FATAL_ERROR "GTest not found but BUILD_TESTS is ON")
    endif()

    if(BUILD_ALL_TESTS)
        message(STATUS "Building all module tests...")
        
        # Only add test directories if they haven't been added already
        if(NOT TARGET library1_tests)
            add_subdirectory(${PROJECT_SOURCE_DIR}/lib/library1/lib1_test ${CMAKE_BINARY_DIR}/lib/library1/lib1_test/bin)
        endif()
        if(NOT TARGET library2_tests)
            add_subdirectory(${PROJECT_SOURCE_DIR}/lib/library2/lib2_test ${CMAKE_BINARY_DIR}/lib/library2/lib2_test/bin)
        endif()
    else()
        message(STATUS "BUILD_ALL_TESTS is OFF. Build module tests manually.")
    endif()
endif()