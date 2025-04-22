# Добавляем поддиректории с библиотеками
add_subdirectory(library1)
add_subdirectory(library2)


# Создаем интерфейсную библиотеку-контейнер (опционально)
add_library(lib_utilities INTERFACE)
target_link_libraries(lib_utilities INTERFACE 
    library1 
    library2
)

# Делаем библиотеки доступными для остального проекта
set(UTILITY_LIBS library1 library2 PARENT_SCOPE)
set(ALL_UTILITIES_TARGET lib_utilities PARENT_SCOPE)
add_library(utils INTERFACE)
target_link_libraries(lib_utilities INTERFACE 
    library1 
    library2
)

# Делаем библиотеки доступными для остального проекта
set(UTILITY_LIBS library1 library2 PARENT_SCOPE)
set(ALL_UTILITIES_TARGET lib_utilities PARENT_SCOPE)