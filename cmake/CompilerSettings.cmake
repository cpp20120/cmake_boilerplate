# CompilerFlags.cmake - Cross-platform compiler flag configuration

# Option configurations
option(ENABLE_EXTRA_WARNINGS "Enable all possible warnings" ON)
option(ENABLE_SANITIZERS "Enable address/thread sanitizers (Clang/GCC only)" OFF)
option(ENABLE_MSVC_SDL "Enable MSVC SDL checks (security)" ON)
option(ENABLE_HARDENING "Enable security hardening flags" ON)
option(ENABLE_LTO "Enable Link Time Optimization" OFF)

# Common compiler flags for all platforms
add_compile_options(
  "$<$<CXX_COMPILER_ID:MSVC>:/utf-8>" # Force UTF-8 encoding on MSVC
  "$<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-fdiagnostics-color=always>" # Colored diagnostics
)

if(MSVC)
  #-----------------------------------------------------------------------------
  # MSVC Compiler Settings
  #-----------------------------------------------------------------------------
  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

  add_compile_options(
    /W4 # Warning level 4
    /WX # Warnings as errors
    /permissive- # Standards-conforming mode
    /Zc:__cplusplus # Proper __cplusplus macro
    /Zc:inline # Remove unreferenced COMDAT
    /MP # Multi-processor compilation
    /nologo # Suppress logo
    /Gw # Optimize global data
    /Gy # Enable function-level linking
    /guard:cf # Enable control flow guard
  )

  if(ENABLE_MSVC_SDL)
    add_compile_options(
      /sdl # Enable additional security checks
      /GS # Buffer security check
    )
  endif()

  # Disable specific warnings if needed
  add_compile_options(
    /wd4068 # Disable unknown pragma warning
    /wd5105 # Disable macro expansion warning
  )

  # Clang-CL specific options (Clang with MSVC compatibility)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC")
    add_compile_options(-mavx2 -fms-compatibility-version=19.29 -Wno-microsoft-enum-forward-reference)
  endif()

  # Common Windows definitions
  add_compile_definitions(
    NOMINMAX
    WIN32_LEAN_AND_MEAN
    _CRT_SECURE_NO_WARNINGS
    _SCL_SECURE_NO_WARNINGS)

  # Linker options
  add_link_options(
    /DEBUG # Generate debug info
    /INCREMENTAL:NO # Disable incremental linking
  )

  if(ENABLE_LTO)
    add_compile_options(/GL) # Whole program optimization
    add_link_options(/LTCG) # Link-time code generation
  endif()

else()
  #-----------------------------------------------------------------------------
  # GCC/Clang Compiler Settings
  #-----------------------------------------------------------------------------
  if(ENABLE_EXTRA_WARNINGS)
    add_compile_options(
      -Wall
      -Wextra
      -Wpedantic
      -Wconversion
      -Wshadow
      -Werror
      -Wformat=2
      -Wnon-virtual-dtor
      -Wold-style-cast
      -Wcast-align
      -Wunused
      -Woverloaded-virtual
      -Wdouble-promotion
      -Wmisleading-indentation)
  endif()

  # Clang-specific options
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(
      -Weverything
      -Wno-c++98-compat
      -Wno-c++98-compat-pedantic
      -Wno-padded
      -Wno-exit-time-destructors
      -Wno-global-constructors)

    if(ENABLE_SANITIZERS)
      set(SANITIZER_TYPES
          address
          thread
          undefined
          leak)
      if(NOT
         SANITIZER
         IN_LIST
         SANITIZER_TYPES)
        message(FATAL_ERROR "Unknown sanitizer: ${SANITIZER}. Valid options: ${SANITIZER_TYPES}")
      endif()

      add_compile_options(-fsanitize=${SANITIZER} "$<$<STREQUAL:${SANITIZER},address>:-fno-omit-frame-pointer>")
      add_link_options(-fsanitize=${SANITIZER})
    endif()
  endif()

  # GCC-specific options
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options(
      -Wduplicated-cond
      -Wlogical-op
      -Wnull-dereference
      -Wuseless-cast
      -Wzero-as-null-pointer-constant)

    # GCC 10+ specific warnings
    if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 10.0)
      add_compile_options(-Warith-conversion)
    endif()
  endif()

  # Hardening (security) options
  if(ENABLE_HARDENING)
    add_compile_options(
      -D_FORTIFY_SOURCE=2
      -fstack-protector-strong
      -fPIE
      "$<$<CXX_COMPILER_ID:GNU>:-fcf-protection=full>")
    add_link_options(-Wl,-z,now -Wl,-z,relro -pie)
  endif()

  # Link Time Optimization
  if(ENABLE_LTO)
    add_compile_options(-flto)
    add_link_options(-flto)
  endif()

  # Position Independent Code (PIC)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)
endif()

#-----------------------------------------------------------------------------
# Common settings for all compilers
#-----------------------------------------------------------------------------
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  add_compile_definitions(DEBUG _DEBUG)
else()
  add_compile_definitions(NDEBUG)
endif()

# Enable RTTI (can be disabled if not needed)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -frtti")

# Visibility settings
if(NOT MSVC)
  add_compile_options(-fvisibility=hidden -fvisibility-inlines-hidden)
endif()

#-----------------------------------------------------------------------------
# Configuration summary
#-----------------------------------------------------------------------------
message(STATUS "Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "Extra warnings: ${ENABLE_EXTRA_WARNINGS}")
message(STATUS "Sanitizers: ${ENABLE_SANITIZERS}")
message(STATUS "Hardening: ${ENABLE_HARDENING}")
message(STATUS "LTO: ${ENABLE_LTO}")
