boilerplate_add_executable(${CMAKE_PROJECT_NAME} SOURCES main.cpp
  LIBRARIES library1::library1 library2::library2 INSTALL)
if(BOILERPLATE_BUILD_TESTS)
  boilerplate_register_check(application_smoke ${CMAKE_PROJECT_NAME} LABELS smoke application)
endif()
boilerplate_pgo_workload(${CMAKE_PROJECT_NAME})
