cmake_minimum_required(VERSION 3.26)
project(ExternalFixture LANGUAGES CXX)
add_library(external SHARED external.cpp)
add_library(external_leaf SHARED leaf.cpp)
target_link_libraries(external PRIVATE external_leaf)
set_target_properties(external external_leaf PROPERTIES INSTALL_NAME_DIR "@rpath" BUILD_WITH_INSTALL_NAME_DIR ON)
file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/external-$<CONFIG>.cmake" CONTENT
  "set(EXTERNAL_LIBRARY [==[$<TARGET_FILE:external>]==])\nset(EXTERNAL_IMPLIB [==[$<TARGET_LINKER_FILE:external>]==])\nset(EXTERNAL_LEAF [==[$<TARGET_FILE:external_leaf>]==])\nset(EXTERNAL_LEAF_IMPLIB [==[$<TARGET_LINKER_FILE:external_leaf>]==])\n")
