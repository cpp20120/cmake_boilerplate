# CompilerFlags.cmake

option(ENABLE_EXTRA_WARNINGS "Enable all possible warnings" ON)
option(ENABLE_SANITIZERS "Enable address/thread sanitizers (Clang/GCC only)" OFF)
option(ENABLE_MSVC_SDL "Enable MSVC SDL checks (security)" ON)
option(ENABLE_HARDENING "Enable security hardening flags" ON)

add_compile_options(
        "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>"
        "$<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-fdiagnostics-color=always>"
)

if(MSVC)
    add_compile_options(
            /W4
            /WX
            /permissive-
            /Zc:__cplusplus
            /Zc:inline
            /MP
            /nologo
    )

    if(ENABLE_MSVC_SDL)
        add_compile_options(/sdl)
    endif()

    if(ENABLE_MSVC_SDL)
        add_compile_options(/RTC-)
    endif()

    if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
        add_compile_options(
                -mavx2
                -fms-compatibility-version=19.29
        )
    endif()

    add_compile_definitions(
            NOMINMAX
            WIN32_LEAN_AND_MEAN
            _CRT_SECURE_NO_WARNINGS
    )
else()  # NOT MSVC
    if(ENABLE_EXTRA_WARNINGS)
        add_compile_options(
                -Wall
                -Wextra
                -Wpedantic
                -Wconversion
                -Wshadow
                -Werror
        )
    endif()

    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        add_compile_options(
                -Weverything
                -Wno-padded
        )

        if(ENABLE_SANITIZERS)
            string(TOLOWER "${SANITIZER}" SANITIZER)
            if(SANITIZER STREQUAL "address")
                add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
            elseif(SANITIZER STREQUAL "thread")
                add_compile_options(-fsanitize=thread)
            elseif(SANITIZER STREQUAL "undefined")
                add_compile_options(-fsanitize=undefined)
            elseif(SANITIZER STREQUAL "leak")
                add_compile_options(-fsanitize=leak)
            else()
                message(FATAL_ERROR "Unknown sanitizer: ${SANITIZER}")
            endif()

            add_link_options(-fsanitize=${SANITIZER})
        endif()
    endif()

    # GCC-specific flags
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        add_compile_options(
                -Wduplicated-cond
                -Wlogical-op
                -Wnull-dereference
        )
    endif()

    # Hardening (security)
    if(ENABLE_HARDENING)
        add_compile_options(
                -D_FORTIFY_SOURCE=2
                -fstack-protector-strong
                "$<$<CXX_COMPILER_ID:GNU>:-fcf-protection=full>"
        )
        add_link_options(-Wl,-z,now,-z,relro)
    endif()
endif()