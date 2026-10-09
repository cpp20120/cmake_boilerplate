cmake_minimum_required(VERSION 3.26)
if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  message(STATUS "Native Linux package selection checks are Linux-only")
  return()
endif()
get_filename_component(_source "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
if(NOT CHECK_BINARY)
  set(CHECK_BINARY "${CMAKE_CURRENT_BINARY_DIR}/out/package-selection-test")
endif()
file(MAKE_DIRECTORY "${CHECK_BINARY}/fake-tools")
# Both backends are deliberately 'installed', regardless of OS family. This
# reproduces the original bug and asserts it cannot recur.
foreach(_tool IN ITEMS rpmbuild dpkg-deb)
  file(WRITE "${CHECK_BINARY}/fake-tools/${_tool}" "#!/bin/sh\nexit 0\n")
  file(CHMOD "${CHECK_BINARY}/fake-tools/${_tool}"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endforeach()
foreach(_case IN ITEMS "debian|ID=ubuntu|TGZ,DEB" "rpm|ID=fedora|TGZ,RPM"
    "arch|ID=cachyos|TGZ" "unknown|ID=custom|TGZ")
  string(REPLACE "|" ";" _fields "${_case}")
  list(GET _fields 0 _label)
  list(GET _fields 1 _release)
  list(GET _fields 2 _wanted)
  string(REPLACE "," ";" _wanted "${_wanted}")
  string(REPLACE ";" "\\;" _encoded "${_wanted}")
  file(WRITE "${CHECK_BINARY}/${_label}.os-release" "${_release}\n")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E env
    "PATH=${CHECK_BINARY}/fake-tools:$ENV{PATH}"
    "${CMAKE_COMMAND}" -S "${_source}" -B "${CHECK_BINARY}/${_label}"
    -G Ninja -DENABLE_PACKAGING=ON
    "-DBOILERPLATE_OS_RELEASE_FILE=${CHECK_BINARY}/${_label}.os-release"
    RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _result EQUAL 0)
    message(FATAL_ERROR "${_label} configure failed: ${_out}\n${_err}")
  endif()
  file(STRINGS "${CHECK_BINARY}/${_label}/CPackConfig.cmake" _actual
    REGEX "^set\\(CPACK_GENERATOR ")
  if(NOT _actual STREQUAL "set(CPACK_GENERATOR \"${_encoded}\")")
    message(FATAL_ERROR "${_label}: expected ${_wanted}, observed ${_actual}")
  endif()
  message(STATUS "${_label}: ${_wanted}")
endforeach()
file(REMOVE_RECURSE "${CHECK_BINARY}")
message(STATUS "Native Linux package selection regression passed")
