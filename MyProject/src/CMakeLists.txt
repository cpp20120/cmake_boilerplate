boilerplate_add_executable(${CMAKE_PROJECT_NAME} SOURCES main.cpp
  LIBRARIES library1::library1 library2::library2 INSTALL)
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE "${PROJECT_SOURCE_DIR}/include")
# Cross-platform executable launcher consumed by the one-command bootstrap.
# Using TARGET_FILE handles suffixes, output directories and build configurations.
add_custom_target(boilerplate_run
  COMMAND "$<TARGET_FILE:${CMAKE_PROJECT_NAME}>"
  DEPENDS ${CMAKE_PROJECT_NAME}
  WORKING_DIRECTORY "$<TARGET_FILE_DIR:${CMAKE_PROJECT_NAME}>"
  USES_TERMINAL VERBATIM)

if(BOILERPLATE_BUILD_TESTS)
  boilerplate_register_check(application_smoke ${CMAKE_PROJECT_NAME} LABELS smoke application)
endif()
boilerplate_pgo_workload(${CMAKE_PROJECT_NAME})
