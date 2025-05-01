# cmake/CPackConfig.cmake

option(ENABLE_PACKAGING "Enable package generation with CPack" OFF)

if(NOT ENABLE_PACKAGING)
  return()
endif()

message(STATUS "Configuring package generation...")

include(InstallRequiredSystemLibraries)

# Базовые настройки
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_CONTACT "cppshizoid@gmail.com")
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_VENDOR "cppshizoid")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Personal C++ Project")
set(CPACK_STRIP_FILES TRUE)

# Настройки компонентов
set(CPACK_COMPONENTS_ALL Runtime Libraries Headers)

# Windows (NSIS)
if(WIN32)
  list(APPEND CPACK_GENERATOR "NSIS")
  set(CPACK_NSIS_MODIFY_PATH ON)
  set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)

  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon.ico")
    set(CPACK_NSIS_MUI_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon.ico")
    set(CPACK_NSIS_MUI_UNIICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/uninstall.ico")
  endif()

  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/installer_banner.bmp")
    set(CPACK_NSIS_BANNER "${CMAKE_CURRENT_SOURCE_DIR}/assets/installer_banner.bmp")
  endif()
endif()

# Linux (DEB/RPM)
if(UNIX AND NOT APPLE)
  list(
    APPEND
    CPACK_GENERATOR
    "DEB"
    "RPM")

  # DEB
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "cppshizoid <cppshizoid@gmail.com>")
  set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
  set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6 (>= 2.27), libstdc++6 (>= 8)")

  # RPM
  set(CPACK_RPM_PACKAGE_RELEASE "1")
  set(CPACK_RPM_PACKAGE_LICENSE "MIT")
  set(CPACK_RPM_PACKAGE_REQUIRES "libstdc++ >= 8, glibc >= 2.27")

  # Общие скрипты
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/postinst")
    set(CPACK_DEBIAN_PACKAGE_CONTROL_EXTRA "${CMAKE_CURRENT_SOURCE_DIR}/scripts/postinst")
    set(CPACK_RPM_POST_INSTALL_SCRIPT_FILE "${CMAKE_CURRENT_SOURCE_DIR}/scripts/postinst")
  endif()
endif()

include(CPack)

message(STATUS "CPack generators: ${CPACK_GENERATOR}")
