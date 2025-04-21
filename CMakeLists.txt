cmake_minimum_required(VERSION 3.26)
project(TEST_PROJECT CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(src)
add_subdirectory(lib)

option(BUILD_TESTS "Build tests" ON)
if(BUILD_TESTS AND BUILD_TESTING)
    enable_testing()
    add_subdirectory(test)
endif()

include(cmake/PlatformSettings.cmake)
include(cmake/CompilerSettings.cmake)
include(cmake/LinkerSettings.cmake)
include(cmake/BuildConfiguration.cmake)
include(cmake/CodeFormatAndAnalysis.cmake)
#include(cmake/ThirdParty.cmake)
#include(cmake/CodeCoverage.cmake)

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    INCLUDES DESTINATION include
)

#include(cmake/CPackConfig.cmake)