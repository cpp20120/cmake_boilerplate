project(lib LANGUAGES CXX)
# Define library target and properties
add_subdirectory(src)
add_library(lib ${SOURCE_FILE})

# Include directories for the library
target_include_directories(${PROJECT_NAME}
    PUBLIC ${PROJECT_SOURCE_DIR}/include
    PRIVATE ${PROJECT_SOURCE_DIR}/src
    )
# Build options for shared and static library
option(BUILD_SHARED_LIB "Build shared library (default: ON)" ON)
option(BUILD_STATIC_LIB "Build static library (default: OFF)" OFF)

if (BUILD_SHARED_LIB)
 set_target_properties(lib PROPERTIES OUTPUT_NAME lib_shared)
 set_target_properties(lib PROPERTIES OUTPUT_NAME_DEBUG lib_shared_d)
 set_target_properties(lib PROPERTIES OUTPUT_NAME_RELEASE lib_shared)
 set_target_properties(lib PROPERTIES SUFFIX ".so")
 set_target_properties(lib PROPERTIES PREFIX "")
 set_target_properties(lib PROPERTIES IMPORTED_LOCATION lib_shared.so)
 set_target_properties(lib PROPERTIES IMPORTED_IMPLIB lib_shared.so)
 set_target_properties(lib PROPERTIES LINK_FLAGS "-Wl,-rpath,\${CMAKE_INSTALL_PREFIX}/lib")
 set_target_properties(lib PROPERTIES BUILD_RPATH ${CMAKE_INSTALL_PREFIX}/lib)
 set_target_properties(lib PROPERTIES SOVERSION 1.0)
 set_target_properties(lib PROPERTIES VERSION 1.0)
 set_target_properties(lib PROPERTIES TYPE SHARED)
endif()

if (BUILD_STATIC_LIB)
 set_target_properties(lib PROPERTIES OUTPUT_NAME lib_static)
 set_target_properties(lib PROPERTIES OUTPUT_NAME_DEBUG lib_static_d)
 set_target_properties(lib PROPERTIES OUTPUT_NAME_RELEASE lib_static)
 set_target_properties(lib PROPERTIES SUFFIX ".a")
 set_target_properties(lib PROPERTIES PREFIX "")
 set_target_properties(lib PROPERTIES TYPE STATIC)
endif()
