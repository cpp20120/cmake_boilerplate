include_guard(GLOBAL)

function(boilerplate_target_modules target)
  cmake_parse_arguments(PARSE_ARGV 1 ARG "SCAN" "" "PUBLIC;PRIVATE")
  if(ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES OR
     (NOT ARG_SCAN AND NOT ARG_PUBLIC AND NOT ARG_PRIVATE))
    message(FATAL_ERROR
      "boilerplate_target_modules(${target} PUBLIC ... PRIVATE ...): invalid arguments")
  endif()
  if(CMAKE_VERSION VERSION_LESS 3.28)
    message(FATAL_ERROR "C++ module file sets require CMake 3.28 or newer")
  endif()
  _boilerplate_real_target(${target} _real_target)
  get_target_property(_imported ${_real_target} IMPORTED)
  if(_imported)
    message(FATAL_ERROR "Target ${target}: cannot add module sources to an imported target")
  endif()
  get_target_property(_standard ${_real_target} CXX_STANDARD)
  if(NOT _standard OR _standard LESS 20)
    message(FATAL_ERROR "Target ${target}: C++ modules require CXX_STANDARD >= 20")
  endif()
  get_target_property(_type ${_real_target} TYPE)
  if(ARG_PUBLIC AND _type STREQUAL "EXECUTABLE")
    message(FATAL_ERROR "Target ${target}: executable modules must be PRIVATE")
  endif()
  # Explicit scanning is required when the caller uses cmake_minimum_required(3.26):
  # CMP0155 is not NEW, so ordinary .cpp module imports/implementations would
  # otherwise be compiled without module flags or dependency ordering.
  set_property(TARGET ${_real_target} PROPERTY CXX_SCAN_FOR_MODULES ON)
  if(ARG_PUBLIC)
    target_sources(${_real_target} PUBLIC
      FILE_SET public_cxx_modules TYPE CXX_MODULES
      BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}" FILES ${ARG_PUBLIC})
  endif()
  if(ARG_PRIVATE)
    target_sources(${_real_target} PRIVATE
      FILE_SET private_cxx_modules TYPE CXX_MODULES
      BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}" FILES ${ARG_PRIVATE})
  endif()
endfunction()

# Enable scanning for direct consumers of a PUBLIC module file set.  Consumers
# with indirect or late-added dependencies can call boilerplate_target_modules(SCAN).
function(_boilerplate_scan_linked_modules target)
  foreach(_dependency IN LISTS ARGN)
    if(TARGET "${_dependency}")
      _boilerplate_real_target("${_dependency}" _dependency_target)
      get_target_property(_module_sets ${_dependency_target} INTERFACE_CXX_MODULE_SETS)
      if(_module_sets)
        boilerplate_target_modules(${target} SCAN)
        return()
      endif()
    endif()
  endforeach()
endfunction()
