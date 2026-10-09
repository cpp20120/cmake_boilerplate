cmake_minimum_required(VERSION 3.26)
project(BoilerplateExampleLibrariesConsumer LANGUAGES CXX)

enable_testing()
find_package(library1 1 CONFIG REQUIRED)
find_package(library2 1 CONFIG REQUIRED)

add_executable(consume_library1 consume_library1.cpp)
target_link_libraries(consume_library1 PRIVATE library1::library1)
add_test(NAME consume_library1 COMMAND consume_library1)

add_executable(consume_library2 consume_library2.cpp)
target_link_libraries(consume_library2 PRIVATE library2::library2)
add_test(NAME consume_library2 COMMAND consume_library2)
