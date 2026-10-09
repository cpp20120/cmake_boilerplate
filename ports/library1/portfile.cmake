# v1.0.0: immutable source commit plus archive integrity check.
vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO cpp20120/cmake_boilerplate
  REF 60b591ca25b2c58d2ece386b7e649b34138bf5fd
  SHA512 3051677843cdae415629bf856f8a0eab3b9f42a94fdab1da988fa8578ee87534ad870dcbc93c824bc213f0bb3f9003026a7f001a4efb7d8d5bb170417d994416)

set(_shared OFF)
set(_static ON)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
  set(_shared ON)
  set(_static OFF)
endif()
vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}/lib/library1"
  OPTIONS
    -DBOILERPLATE_BUILD_SHARED=${_shared}
    -DBOILERPLATE_BUILD_STATIC=${_static}
    -DBOILERPLATE_INSTALL=ON
    -DBOILERPLATE_BUILD_TESTS=OFF
    -DBOILERPLATE_BUILD_BENCHMARKS=OFF
    -DBUILD_TESTING=OFF
  MAYBE_UNUSED_VARIABLES BUILD_TESTING)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME library1 CONFIG_PATH lib/cmake/library1)

vcpkg_copy_pdbs()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
