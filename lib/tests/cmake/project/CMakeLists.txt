cmake_minimum_required(VERSION 3.26)
project(GenericLibraryFixture VERSION 2.1.0 LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_DIR}/Boilerplate.cmake")

function(fixture_project_configure)
  set_property(GLOBAL PROPERTY FIXTURE_PROJECT_CONFIGURED TRUE)
endfunction()
function(fixture_project_finalize)
  set_property(GLOBAL PROPERTY FIXTURE_PROJECT_FINALIZED TRUE)
endfunction()
boilerplate_define_project_capability(fixture-project
  INHERITS project-minimal
  CONFIGURE_HOOKS fixture_project_configure
  FINALIZE_HOOKS fixture_project_finalize)
boilerplate_project(CAPABILITIES fixture-project property-testing fuzzing build-info diagnostics)
get_property(_fixture_project_configured GLOBAL PROPERTY FIXTURE_PROJECT_CONFIGURED)
if(NOT _fixture_project_configured)
  message(FATAL_ERROR "Project capability configure hook did not run")
endif()

function(fixture_policy_hook target)
  set_property(TARGET ${target} PROPERTY FIXTURE_POLICY_HOOK_RAN TRUE)
endfunction()
boilerplate_define_policy(fixture-base
  ENABLE_NATIVE OFF
  WARNINGS_AS_ERRORS ON
  HOOKS fixture_policy_hook)
boilerplate_define_policy(fixture-runtime INHERITS fixture-base gc-sections)

boilerplate_add_library(sample_math SOURCES math.cpp INCLUDE_DIR include
  POLICIES fixture-runtime
  SHARED_POLICIES no-plt
  POLICY_OPTIONS WARNINGS_AS_ERRORS OFF)
foreach(kind IN ITEMS shared static)
  if(TARGET sample_math_${kind})
    boilerplate_get_target_setting(sample_math_${kind} ENABLE_NATIVE _native)
    boilerplate_get_target_setting(sample_math_${kind} ENABLE_GC_SECTIONS _gc)
    boilerplate_get_target_setting(sample_math_${kind} WARNINGS_AS_ERRORS _werror)
    boilerplate_get_target_setting(sample_math_${kind} ENABLE_NO_PLT _no_plt)
    get_target_property(_hook sample_math_${kind} FIXTURE_POLICY_HOOK_RAN)
    set(_variant_bad FALSE)
    if(kind STREQUAL "shared" AND NOT _no_plt)
      set(_variant_bad TRUE)
    elseif(kind STREQUAL "static" AND _no_plt)
      set(_variant_bad TRUE)
    endif()
    if(_native OR NOT _gc OR _werror OR NOT _hook OR _variant_bad)
      message(FATAL_ERROR "Policy composition failed for sample_math_${kind}: native=${_native}, gc=${_gc}, werror=${_werror}, no_plt=${_no_plt}, hook=${_hook}")
    endif()
  endif()
endforeach()

# A minimal target must reset expensive project defaults instead of inheriting
# the surrounding build's optimization/sanitizer policy.
boilerplate_add_executable(policy_minimal_probe SOURCES policy_probe.cpp POLICIES minimal)
foreach(setting IN ITEMS ENABLE_NATIVE LTO_MODE PGO_MODE SANITIZER)
  boilerplate_get_target_setting(policy_minimal_probe ${setting} _value)
  if(setting STREQUAL "ENABLE_NATIVE")
    if(_value)
      message(FATAL_ERROR "minimal policy leaked native tuning")
    endif()
  elseif(NOT _value MATCHES "^(none)$")
    message(FATAL_ERROR "minimal policy leaked ${setting}=${_value}")
  endif()
endforeach()


# Domain policies are composable capabilities. Fake imported dependencies make
# this test independent from Qt/Vulkan packages while exercising the hooks.
foreach(_qt IN ITEMS Core Gui Widgets)
  add_library(Qt6::${_qt} INTERFACE IMPORTED)
endforeach()
add_library(Vulkan::Vulkan INTERFACE IMPORTED)
add_library(glfw INTERFACE IMPORTED)
add_library(glm::glm INTERFACE IMPORTED)
add_library(imgui::imgui INTERFACE IMPORTED)
add_executable(domain_policy_probe EXCLUDE_FROM_ALL policy_probe.cpp)
boilerplate_apply_target_policy(domain_policy_probe POLICIES minimal qt-widgets graphics-vulkan-imgui)
get_target_property(_domain_links domain_policy_probe LINK_LIBRARIES)
get_target_property(_automoc domain_policy_probe AUTOMOC)
get_target_property(_autouic domain_policy_probe AUTOUIC)
get_target_property(_autorcc domain_policy_probe AUTORCC)
foreach(_required IN ITEMS Qt6::Core Qt6::Gui Qt6::Widgets Vulkan::Vulkan glfw glm::glm imgui::imgui)
  if(NOT _required IN_LIST _domain_links)
    message(FATAL_ERROR "Domain policy did not link ${_required}: ${_domain_links}")
  endif()
endforeach()
if(NOT _automoc OR NOT _autouic OR NOT _autorcc)
  message(FATAL_ERROR "Qt widgets policy did not enable AUTOGEN properties")
endif()

# Runtime archetypes are inspectable before compiler-specific application.
add_executable(runtime_policy_probe EXCLUDE_FROM_ALL policy_probe.cpp)
boilerplate_configure_target(runtime_policy_probe POLICIES runtime-dagflow)
foreach(_pair IN ITEMS "ENABLE_NATIVE;ON" "LTO_MODE;full" "USE_LLD;ON" "ENABLE_ICF;ON"
                       "ENABLE_NO_SEMANTIC_INTERPOSITION;ON")
  list(GET _pair 0 _setting)
  list(GET _pair 1 _expected)
  boilerplate_get_target_setting(runtime_policy_probe ${_setting} _actual)
  if(NOT "${_actual}" STREQUAL "${_expected}")
    message(FATAL_ERROR "runtime-dagflow ${_setting}: expected ${_expected}, got ${_actual}")
  endif()
endforeach()
add_executable(web_policy_probe EXCLUDE_FROM_ALL policy_probe.cpp)
boilerplate_configure_target(web_policy_probe POLICIES runtime-webserver)
boilerplate_get_target_setting(web_policy_probe LTO_MODE _web_lto)
boilerplate_get_target_setting(web_policy_probe ENABLE_NO_SEMANTIC_INTERPOSITION _web_interpose)
if(NOT _web_lto STREQUAL "thin" OR _web_interpose)
  message(FATAL_ERROR "runtime-webserver policy composition is wrong")
endif()


# Testing-stack helpers are dependency-backend agnostic. Fake interface targets
# let the generic fixture exercise registration without downloading third-party code.
add_library(GTest::gtest_main INTERFACE IMPORTED)
add_library(rapidcheck INTERFACE IMPORTED)
add_library(rapidcheck_gtest INTERFACE IMPORTED)
boilerplate_add_property_test(property_policy_probe SOURCES policy_probe.cpp)
get_property(_property_targets GLOBAL PROPERTY BOILERPLATE_PROPERTY_TEST_TARGETS)
if(NOT property_policy_probe IN_LIST _property_targets)
  message(FATAL_ERROR "Property test target was not registered")
endif()
function(link_fuzztest target)
  # Fixture stand-in for Google FuzzTest's CMake helper.
endfunction()
boilerplate_add_fuzztest(fuzztest_policy_probe SOURCES policy_probe.cpp MODE unit)
get_property(_fuzztest_targets GLOBAL PROPERTY BOILERPLATE_FUZZTEST_TARGETS)
if(NOT fuzztest_policy_probe IN_LIST _fuzztest_targets)
  message(FATAL_ERROR "FuzzTest target was not registered")
endif()

# Self-contained harness: CMake owns both the build and process execution.
boilerplate_add_executable(harness_probe SOURCES harness_probe.cpp POLICIES minimal)
boilerplate_add_harness(fixture_harness TARGET harness_probe
  CASES "${CMAKE_CURRENT_SOURCE_DIR}/harness_cases.json"
  ROUNDS 2 WARMUP_RUNS 1 TIMEOUT 10 AFFINITY physical RANDOMIZE
  METRICS value INVARIANTS checksum METADATA fixture=yes)

# Exercise sources added after the profile helper registered its dependencies.
foreach(kind IN ITEMS shared static)
  if(TARGET sample_math_${kind})
    target_sources(sample_math_${kind} PRIVATE late.cpp)
  endif()
endforeach()
boilerplate_add_test(sample_check SOURCES main.cpp LIBRARIES sample_math::sample_math)
boilerplate_pgo_workload(sample_check)
boilerplate_add_scenario(fixture_first TARGET sample_check GROUP fixture REPEATS 1 WARMUP 0)
boilerplate_add_scenario(fixture_second TARGET sample_check GROUP fixture REPEATS 1 WARMUP 0)

boilerplate_finalize_project()
get_property(_fixture_project_finalized GLOBAL PROPERTY FIXTURE_PROJECT_FINALIZED)
if(NOT _fixture_project_finalized)
  message(FATAL_ERROR "Project capability finalize hook did not run")
endif()
