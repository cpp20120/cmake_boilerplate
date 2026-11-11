cmake_minimum_required(VERSION 3.28)
project(BoilerplateModulesConsumer LANGUAGES CXX)
include(CTest)
find_package(math CONFIG REQUIRED)
add_executable(consumer_shared main.cpp)
add_executable(consumer_static main.cpp)
foreach(_kind IN ITEMS shared static)
  target_compile_features(consumer_${_kind} PRIVATE cxx_std_23)
  set_target_properties(consumer_${_kind} PROPERTIES
    CXX_EXTENSIONS OFF
    CXX_SCAN_FOR_MODULES ON)
  target_link_libraries(consumer_${_kind} PRIVATE math::${_kind})
  add_test(NAME consumer_${_kind} COMMAND consumer_${_kind} 48)
endforeach()
