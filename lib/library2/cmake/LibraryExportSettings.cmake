include(GenerateExportHeader)

file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/include")

if(TARGET library2)
  generate_export_header(
    library2
    BASE_NAME
    LIB
    EXPORT_MACRO_NAME
    LIB_EXPORT
    EXPORT_FILE_NAME
    "${CMAKE_CURRENT_BINARY_DIR}/include/lib_export.h"
    STATIC_DEFINE
    LIB_STATIC_DEFINE)
  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/include/lib_export.h" DESTINATION include)

  # 4. Включаем директорию с экспорт-заголовком
  target_include_directories(
    library2 PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
                    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include> $<INSTALL_INTERFACE:include>)
else()
  message(WARNING "Target 'library2' not found - export headers not generated")
endif()
