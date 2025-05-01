# Include what you use
find_program(IWYU_PROGRAM NAMES include-what-you-use)
if(IWYU_PROGRAM)
  set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE ${IWYU_PROGRAM})
endif()

# Code formatting
file(
  GLOB_RECURSE
  ALL_SOURCE_FILES
  "*.cpp"
  "*.h"
  "*.hpp")

find_program(CLANG_FORMAT "clang-format")
if(CLANG_FORMAT)
  add_custom_target(
    format
    COMMAND ${CLANG_FORMAT} -i --style=file ${ALL_SOURCE_FILES}
    COMMENT "Running clang-format on source files")
endif()

# Static analysis
find_program(CLANG_TIDY "clang-tidy")
if(CLANG_TIDY)
  set(CMAKE_CXX_CLANG_TIDY ${CLANG_TIDY} -extra-arg=-Wno-unknown-warning-option --header-filter=.*)
endif()

# ccache configuration
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PROGRAM})
  set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PROGRAM})
endif()
