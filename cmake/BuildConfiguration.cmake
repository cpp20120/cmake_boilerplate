# Configurations
set(CMAKE_CONFIGURATION_TYPES
    "Debug;Release;RelWithDebInfo;MinSizeRel"
    CACHE STRING "" FORCE)

# Debug configuration
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  if(MSVC)
    target_compile_options(
      ${PROJECT_NAME}
      PRIVATE /sdl
              /Od
              /Zi
              /RTC1)
    target_link_options(${PROJECT_NAME} PRIVATE /DEBUG)
  else()
    target_compile_options(
      ${PROJECT_NAME}
      PRIVATE -g
              -O0
              #-fno-omit-frame-pointer
              #-fsanitize=address
              #-fsanitize=undefined
              #-fno-optimize-sibling-calls
              #-fsanitize=thread
    )
    target_link_options(
      ${PROJECT_NAME} PRIVATE #-fsanitize=address
                              #-fsanitize=undefined
    )
  endif()
endif()

# Release configuration
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  include(CheckIPOSupported)
  check_ipo_supported(RESULT result OUTPUT output)
  if(result)
    set_target_properties(${PROJECT_NAME} PROPERTIES INTERPROCEDURAL_OPTIMIZATION TRUE)
  else()
    message(WARNING "IPO is not supported: ${output}")
  endif()

  if(NOT MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE -O3 -march=native -DNDEBUG)
  else()
    target_compile_options(${PROJECT_NAME} PRIVATE /O2 /Ob2 /DNDEBUG)
  endif()
endif()
