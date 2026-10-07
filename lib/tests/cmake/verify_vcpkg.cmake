cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<temporary build directory>")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/packaging/VcpkgPackaging.cmake")
set(_ports "${CHECK_BINARY}/ports")
boilerplate_vcpkg_port(local-example VERSION 1.2.3
  DESCRIPTION "A \"quoted\" description\nwith a newline"
  SPDX_LICENSE MIT LICENSE_FILE LICENSE PACKAGES my_math
  SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../.." SOURCE_SUBDIR library1
  DEPENDENCIES fmt OPTIONS -DMY_FEATURE=ON OUTPUT_DIRECTORY "${_ports}")
file(READ "${_ports}/local-example/vcpkg.json" _manifest)
string(JSON _description GET "${_manifest}" description)
if(NOT _description STREQUAL "A \"quoted\" description\nwith a newline")
  message(FATAL_ERROR "JSON escaping changed metadata")
endif()
string(JSON _dependency GET "${_manifest}" dependencies 2)
if(NOT _dependency STREQUAL "fmt")
  message(FATAL_ERROR "Lost dependency")
endif()
string(REPEAT a 128 _hash)
boilerplate_vcpkg_port(archive-example VERSION 1.2.3
  URL https://example.invalid/library.tar.gz SHA512 "${_hash}"
  LICENSE_FILE LICENSE PACKAGES my_math OUTPUT_DIRECTORY "${_ports}")
file(READ "${_ports}/archive-example/portfile.cmake" _portfile)
if(NOT _portfile MATCHES "vcpkg_extract_source_archive" OR
   NOT _portfile MATCHES "SHA512 ${_hash}")
  message(FATAL_ERROR "Archive extraction/hash missing")
endif()
# Invalid hashes must fail at configure time, before producing a broken port.
file(WRITE "${CHECK_BINARY}/invalid.cmake"
  "include(\"${CMAKE_CURRENT_LIST_DIR}/../../cmake/packaging/VcpkgPackaging.cmake\")\nboilerplate_vcpkg_port(bad VERSION 1 URL https://example.invalid/a SHA512 0 LICENSE_FILE LICENSE PACKAGES bad)\n")
execute_process(COMMAND "${CMAKE_COMMAND}" -P "${CHECK_BINARY}/invalid.cmake"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
if(_result EQUAL 0 OR NOT _err MATCHES "128-digit SHA512")
  message(FATAL_ERROR "Invalid SHA512 was not rejected: ${_out}${_err}")
endif()
message(STATUS "vcpkg port generation checks passed")
