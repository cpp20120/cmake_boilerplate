# Compiler-specific settings
if(MSVC)
    # MSVC/clang-cl specific settings
    add_compile_options(
        /W4
        /WX
        /utf-8
        /permissive-
        /Zc:__cplusplus
        /Zc:inline
    )
    
    if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
        # clang-cl specific options
        add_compile_options(
            -mavx2
            -fms-compatibility-version=19.29
        )
    endif()
else()
    add_compile_options(
        -Wall
        -Wextra
        -Wpedantic
        -Wconversion
        -Wshadow
        -Werror
    )
    
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        add_compile_options(
            -Weverything
            -Wno-padded
            -fsanitize=thread
        )
    endif()
    
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        add_compile_options(
            -Wduplicated-cond
            -Wlogical-op
            -Wnull-dereference
        )
    endif()
endif()

# Windows specific settings
if(WIN32)
    add_compile_definitions(
        NOMINMAX
        WIN32_LEAN_AND_MEAN
        _CRT_SECURE_NO_WARNINGS
    )

    if(MSVC)
        add_compile_options(/MP /W3
            /utf-8
            /sdl
            /nologo
        )
    endif()
endif()