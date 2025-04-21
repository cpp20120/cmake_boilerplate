# lib/cmake/LibraryCompilerSettings.cmake
if(MSVC)
    target_compile_options(lib PRIVATE /W4 /WX)
else()
    target_compile_options(lib PRIVATE -Wall -Wextra)

    # Только для Linux/Unix
    if(UNIX AND NOT APPLE)
        target_compile_options(lib PRIVATE -fPIC)
    endif()
endif()

# Для shared библиотек
if(BUILD_SHARED_LIBS)
    target_compile_definitions(lib PRIVATE LIB_EXPORTS)
    if(NOT WIN32)
        target_compile_options(lib PRIVATE -fPIC)
    endif()
endif()