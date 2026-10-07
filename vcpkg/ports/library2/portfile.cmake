# Local development port; resolve the checkout relative to this file.
get_filename_component(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(_shared OFF)
set(_static ON)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
  set(_shared ON)
  set(_static OFF)
endif()
vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}/lib/library2"
  OPTIONS
    -DBOILERPLATE_BUILD_SHARED=${_shared}
    -DBOILERPLATE_BUILD_STATIC=${_static}
    -DBOILERPLATE_INSTALL=ON
    -DBOILERPLATE_BUILD_TESTS=OFF
    -DBOILERPLATE_BUILD_BENCHMARKS=OFF
    -DBUILD_TESTING=OFF
  MAYBE_UNUSED_VARIABLES BUILD_TESTING)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME library2 CONFIG_PATH lib/cmake/library2)

vcpkg_copy_pdbs()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
