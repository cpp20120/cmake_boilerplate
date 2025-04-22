cmake_minimum_required(VERSION 3.26)
project(lib2 LANGUAGES CXX)

add_subdirectory(src)
#add_subdirectory(test)

# Версионирование
set_target_properties(lib2 PROPERTIES
        VERSION 1.0.0
        SOVERSION 1
)
include(cmake/LibraryExportSettings.cmake)
include(cmake/LibraryCompilerSettings.cmake)
include(cmake/LibraryLinkageSettings.cmake)
#include(cmake/LibraryInstallSettings.cmake)

include(cmake/LibraryCP.cmake)

option(BUILD_SHARED_LIBS "Build as shared library" ON)
option(BUILD_TESTING "Build tests" OFF) 

configure_library_type(lib2)
include(cmake/LibraryLinkageSettings.cmake) 

target_include_directories(lib2 PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

