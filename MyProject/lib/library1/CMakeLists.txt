cmake_minimum_required(VERSION 3.26)
project(library1 VERSION 1.0.0 LANGUAGES CXX)

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/Boilerplate.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/Policies.cmake")

# library1 is intentionally dependency-free.  It demonstrates a consumer-local
# policy pack and independent shared/static variant policy composition.
boilerplate_add_library(library1
  VERSION "${PROJECT_VERSION}"
  SOURCES src/lib.cpp
  INCLUDE_DIR include
  POLICIES example-library1
  SHARED_POLICIES example-library1-shared
  STATIC_POLICIES example-library1-static)
