option(BUILD_ALL_TESTS "Build all module tests automatically" ON)
enable_testing()
if(BUILD_TESTS AND BUILD_TESTING)
    # First find the GTest package
    find_package(GTest CONFIG REQUIRED)


    if(TARGET GTest::gtest)
        message(STATUS "Using GTest from root configuration")
    else()
        message(FATAL_ERROR "GTest not found but BUILD_TESTS is ON")
    endif()

    if(BUILD_ALL_TESTS)
        message(STATUS "Building all module tests...")
        
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