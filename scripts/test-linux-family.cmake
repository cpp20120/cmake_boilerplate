cmake_minimum_required(VERSION 3.26)
include("${CMAKE_CURRENT_LIST_DIR}/../lib/cmake/packaging/LinuxFamily.cmake")
if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  message(STATUS "Linux-family detection tests skipped on non-Linux host")
  return()
endif()
if(NOT CHECK_BINARY)
  set(CHECK_BINARY "${CMAKE_CURRENT_BINARY_DIR}/out/linux-family-test")
endif()
file(MAKE_DIRECTORY "${CHECK_BINARY}")
set(BOILERPLATE_OS_RELEASE_FILE "${CHECK_BINARY}/os-release")
foreach(_fixture IN ITEMS
  "arch|ID=arch|arch"
  "cachyos|ID=cachyos|arch"
  "manjaro|ID=manjaro|arch"
  "ubuntu|ID=ubuntu|debian"
  "debianlike|ID=custom\nID_LIKE=\"debian ubuntu\"|debian"
  "fedora|ID=fedora|rpm"
  "rhel_like|ID=custom\nID_LIKE=\"rhel fedora\"|rpm"
  "rpm_tools_wrong|ID=ubuntu|debian"
  "generic|ID=custom|generic")
  string(REPLACE "|" ";" _parts "${_fixture}")
  list(GET _parts 0 _label)
  list(GET _parts 1 _text)
  list(GET _parts 2 _expected)
  file(WRITE "${BOILERPLATE_OS_RELEASE_FILE}" "${_text}\n")
  boilerplate_linux_family(_actual)
  if(NOT _actual STREQUAL _expected)
    message(FATAL_ERROR "${_label}: expected ${_expected}, got ${_actual}")
  endif()
endforeach()
file(REMOVE_RECURSE "${CHECK_BINARY}")
message(STATUS "Linux-family tests passed")
