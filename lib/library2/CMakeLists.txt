cmake_minimum_required(VERSION 3.26)
project(library2 VERSION 1.0.0 LANGUAGES CXX)

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/Boilerplate.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/Policies.cmake")
find_package(Threads REQUIRED)

# library2 intentionally exercises a different path: a public CMake package
# dependency, a custom installed Config.cmake, a different policy pack and PCH.
boilerplate_add_library(library2
  VERSION "${PROJECT_VERSION}"
  SOURCES src/lib.cpp
  INCLUDE_DIR include
  PUBLIC_LIBRARIES Threads::Threads
  PACKAGE_CONFIG "${CMAKE_CURRENT_LIST_DIR}/cmake/Library2Config.cmake.in"
  POLICIES example-library2
  SHARED_POLICIES example-library2-shared
  STATIC_POLICIES example-library2-static)

foreach(_kind IN ITEMS shared static)
  if(TARGET library2_${_kind})
    boilerplate_enable_pch(library2_${_kind} HEADERS "<thread>" "<utility>")
  endif()
endforeach()
