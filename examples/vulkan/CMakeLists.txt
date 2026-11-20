cmake_minimum_required(VERSION 3.26)
project(BoilerplateVulkanSmoke LANGUAGES CXX)

find_package(VulkanHeaders CONFIG REQUIRED)
find_package(VulkanLoader CONFIG REQUIRED)
find_program(VULKAN_SHADER_COMPILER NAMES glslang glslangValidator
  PATHS "${VCPKG_INSTALLED_DIR}/${VCPKG_HOST_TRIPLET}/tools/glslang"
  NO_DEFAULT_PATH REQUIRED)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../lib/cmake/platforms/Shaders.cmake")

add_executable(vulkan_smoke smoke.cpp)
target_compile_features(vulkan_smoke PRIVATE cxx_std_20)
target_link_libraries(vulkan_smoke PRIVATE Vulkan::Headers Vulkan::Loader)
boilerplate_add_glsl_shaders(vulkan_smoke
  SOURCES verify.comp SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
  COMPILER "${VULKAN_SHADER_COMPILER}" BACKEND glslang COPY_TO_RUNTIME)

enable_testing()
add_test(NAME vulkan-device COMMAND vulkan_smoke --check)
add_test(NAME vulkan-dispatch COMMAND vulkan_smoke "$<TARGET_FILE_DIR:vulkan_smoke>/shaders/verify.comp.spv")
set_tests_properties(vulkan-device PROPERTIES FIXTURES_SETUP vulkan_device LABELS vulkan TIMEOUT 30)
set_tests_properties(vulkan-dispatch PROPERTIES FIXTURES_REQUIRED vulkan_device LABELS vulkan TIMEOUT 30)
