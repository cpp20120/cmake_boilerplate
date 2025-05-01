# lib/cmake/LibraryInstallSettings.cmake
if(NOT DEFINED PROJECT_VERSION)
  set(PROJECT_VERSION 1.0.0) # Значение по умолчанию
  message(WARNING "PROJECT_VERSION not set, using default: ${PROJECT_VERSION}")
endif()
# Установка самой библиотеки и заголовков
install(
  TARGETS library1
  EXPORT libTargets
  ARCHIVE DESTINATION library1
  LIBRARY DESTINATION library1
  RUNTIME DESTINATION bin
  INCLUDES
  DESTINATION include)

install(DIRECTORY include/ DESTINATION include)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/lib_export.h" DESTINATION include)

# Генерация конфигурационных файлов для пакета
include(CMakePackageConfigHelpers)

configure_package_config_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake/libConfig.cmake.in"
                              "${CMAKE_CURRENT_BINARY_DIR}/libConfig.cmake" INSTALL_DESTINATION lib/cmake/library1)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/libConfigVersion.cmake"
  VERSION ${PROJECT_VERSION}
  COMPATIBILITY SameMajorVersion)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/libConfig.cmake" "${CMAKE_CURRENT_BINARY_DIR}/libConfigVersion.cmake"
        DESTINATION lib/cmake/library1)
