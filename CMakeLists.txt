cmake_minimum_required(VERSION 3.26)
project(TEST_PROJECT CXX)

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE STRING "Vcpkg toolchain file")
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(src)
add_subdirectory(lib)

find_package(GTest CONFIG REQUIRED)
if(GTest_FOUND)
    message(STATUS "GTest found: ${GTest_DIR}")
else()
    message(FATAL_ERROR "GTest not found")
endif()

option(BUILD_TESTS "Build tests" ON)
option(BUILD_ALL_TESTS "Build and run all module tests together" ON)

add_subdirectory(tests)

list(APPEND CMAKE_PREFIX_PATH "${CMAKE_BINARY_DIR}/vcpkg_installed/x64-windows")


if(BUILD_TESTS AND BUILD_TESTING)
    enable_testing()

    if(EXISTS "${CMAKE_SOURCE_DIR}/test/CMakeLists.txt")
        add_subdirectory(test)
    endif()

    if(BUILD_ALL_TESTS)
        foreach(module_dir IN LISTS LIBRARY_MODULE_DIRS)
            if(EXISTS "${module_dir}/test/CMakeLists.txt")
                add_subdirectory(${module_dir}/test)
            endif()
        endforeach()
    endif()
endif()

include(cmake/PlatformSettings.cmake)
include(cmake/CompilerSettings.cmake)
include(cmake/LinkerSettings.cmake)
include(cmake/BuildConfiguration.cmake)
include(cmake/CodeFormatAndAnalysis.cmake)
#include(cmake/ThirdParty.cmake)
#include(cmake/CodeCoverage.cmake)
#include(cmake/ShaderCompilation.cmake)

install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    INCLUDES DESTINATION include
)

include(cmake/CPackConfig.cmake)