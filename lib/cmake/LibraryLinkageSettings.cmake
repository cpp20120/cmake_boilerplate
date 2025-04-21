

# 5. Подключаем остальные настройки ПОСЛЕ создания цели
include(cmake/LibraryCompilerSettings.cmake)
include(cmake/LibraryExportSettings.cmake)

# 6. Функция для настройки типа библиотеки (теперь в основном файле)
function(configure_library_type TARGET_NAME)
    message(STATUS "Configuring library type for ${TARGET_NAME}")

    if(BUILD_SHARED_LIBS)
        set_target_properties(${TARGET_NAME} PROPERTIES
                POSITION_INDEPENDENT_CODE ON
                OUTPUT_NAME "${TARGET_NAME}_shared"
        )

        if(WIN32)
            set_target_properties(${TARGET_NAME} PROPERTIES
                    WINDOWS_EXPORT_ALL_SYMBOLS TRUE
                    SUFFIX ".dll"
                    PREFIX ""
            )
        else()
            set_target_properties(${TARGET_NAME} PROPERTIES
                    SUFFIX ".so"
                    PREFIX "lib"
            )
        endif()
    else()
        set_target_properties(${TARGET_NAME} PROPERTIES
                OUTPUT_NAME "${TARGET_NAME}_static"
        )

        if(WIN32)
            set_target_properties(${TARGET_NAME} PROPERTIES
                    SUFFIX ".lib"
                    PREFIX ""
            )
        else()
            set_target_properties(${TARGET_NAME} PROPERTIES
                    SUFFIX ".a"
                    PREFIX "lib"
            )
        endif()
    endif()
endfunction()

# 7. Вызываем функцию конфигурации
configure_library_type(lib)

# 8. Версионирование
set(LIB_VERSION 1.0.0)
set_target_properties(lib PROPERTIES
        VERSION ${LIB_VERSION}
        SOVERSION 1
)

# 9. Директории include
target_include_directories(lib PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

# 10. Установка
include(cmake/LibraryInstallSettings.cmake)