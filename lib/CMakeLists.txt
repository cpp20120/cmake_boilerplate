cmake_minimum_required(VERSION 3.26)
project(lib LANGUAGES CXX)

add_subdirectory(src)
add_subdirectory(test)

# Версионирование
set_target_properties(lib PROPERTIES
        VERSION ${LIB_VERSION}
        SOVERSION 1
)

include(cmake/LibraryPlatformSettings.cmake)
include(cmake/LibraryCompilerSettings.cmake)
include(cmake/LibraryExportSettings.cmake)

include(cmake/LibraryCP.cmake)

option(BUILD_SHARED_LIBS "Build as shared library" ON)
option(BUILD_TESTING "Build tests" ON) 

configure_library_type(lib)
include(cmake/LibraryLinkageSettings.cmake) 

target_include_directories(lib PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

include(cmake/LibraryInstallSettings.cmake)
target_compile_features(${LIBRARY_OUTPUT_NAME} PUBLIC cxx_std_23)