# Full-framework bootstrap is deliberately a thin facade over the standalone
# reusable core so application projects do not need to know its physical path.
include_guard(GLOBAL)
if(DEFINED BOILERPLATE_CORE_MODULE_DIR)
  get_filename_component(_boilerplate_core "${BOILERPLATE_CORE_MODULE_DIR}" ABSOLUTE)
else()
  get_filename_component(_boilerplate_core "${CMAKE_CURRENT_LIST_DIR}/../lib/cmake" ABSOLUTE)
endif()
include("${_boilerplate_core}/Bootstrap.cmake")
