cmake_minimum_required(VERSION 3.26)
project(
  library2
  LANGUAGES CXX
  VERSION 1.0.0)

add_subdirectory(src)

# Версионирование

include(cmake/LibraryExportSettings.cmake)
include(cmake/LibraryCompilerSettings.cmake)
include(cmake/LibraryLinkageSettings.cmake)
#include(cmake/LibraryInstallSettings.cmake)

include(cmake/LibraryCP.cmake)

option(BUILD_SHARED_LIBS "Build as shared library" OFF)
option(BUILD_TESTS "Build tests" ON)

configure_library_type(library2)

target_include_directories(library2 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
                                           $<INSTALL_INTERFACE:include>)

set_target_properties(library2 PROPERTIES VERSION 1.0.0 SOVERSION 1)

include(cmake/LibraryInstallSettings.cmake)
