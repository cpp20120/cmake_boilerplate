# Main CMakeLists.txt
cmake_minimum_required(VERSION 3.26)
project(TEST_PROJECT CXX)

# docs
option(BUILD_DOCS "Build documentation" ON)
if (BUILD_DOCS)
    add_subdirectory(docs)
endif ()

# Vcpkg integration
if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake"
        CACHE STRING "Vcpkg toolchain file")
endif()

# Standard settings
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# nvim/vscode clangd helper
set(CMAKE_EXPORT_COMPILE_COMMANDS OFF)

# Output directories
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Add main project components
add_subdirectory(src)
add_subdirectory(lib)
# add tests
set(BUILD_ALL_TESTS ON CACHE BOOL "Build all tests" FORCE)
message(STATUS "BUILD_ALL_TESTS value: ${BUILD_ALL_TESTS} (defined at ${CMAKE_CURRENT_LIST_FILE}:${CMAKE_CURRENT_LIST_LINE})")
enable_testing()
option(BUILD_ALL_TESTS "Build tests" ON)
add_subdirectory(tests)

# Include additional configurations
include(cmake/PlatformSettings.cmake)
include(cmake/CompilerSettings.cmake)
include(cmake/LinkerSettings.cmake)
include(cmake/BuildConfiguration.cmake)
include(cmake/CodeFormatAndAnalysis.cmake)

# Installation
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    INCLUDES DESTINATION include
)

include(cmake/CPackConfig.cmake)
