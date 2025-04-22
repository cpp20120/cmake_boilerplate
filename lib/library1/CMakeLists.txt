cmake_minimum_required(VERSION 3.26)
project(lib1 LANGUAGES CXX)

add_subdirectory(src)
#add_subdirectory(test)

# Версионирование
set_target_properties(lib1 PROPERTIES
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

configure_library_type(lib1)

target_include_directories(lib1 PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

#include(cmake/LibraryInstallSettings.cmake)
