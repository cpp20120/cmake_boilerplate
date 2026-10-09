cmake_minimum_required(VERSION 3.26)
project(RegistryConsumer LANGUAGES CXX)

find_package(library1 1 CONFIG REQUIRED)
find_package(library2 1 CONFIG REQUIRED)

add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE library1::library1 library2::library2)
target_compile_features(consumer PRIVATE cxx_std_17)

# Catch accidental source-tree targets and test the triplet's selected variant.
foreach(name IN ITEMS library1 library2)
  get_target_property(imported ${name}::${name} IMPORTED)
  if(NOT imported)
    message(FATAL_ERROR "${name} must be an installed, imported target")
  endif()
  if(DEFINED EXPECT_LINKAGE)
    get_target_property(kind ${name}::${name} TYPE)
    if(NOT kind STREQUAL "${EXPECT_LINKAGE}_LIBRARY")
      message(FATAL_ERROR "${name}: expected ${EXPECT_LINKAGE}, got ${kind}")
    endif()
  endif()
endforeach()

enable_testing()
add_test(NAME registry-consumer COMMAND consumer)
