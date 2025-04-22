add_executable(${CMAKE_PROJECT_NAME} main.cpp)
target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE lib1 lib2)

if(WIN32 AND BUILD_SHARED_LIBS)
    # Альтернативный вариант (универсальный)
    add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_FILE:lib1>
            $<TARGET_FILE_DIR:${CMAKE_PROJECT_NAME}>
            COMMENT "Copying DLL to executable directory"
    )
    add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_FILE:lib2>
            $<TARGET_FILE_DIR:${CMAKE_PROJECT_NAME}>
            COMMENT "Copying DLL to executable directory"
    )
endif()