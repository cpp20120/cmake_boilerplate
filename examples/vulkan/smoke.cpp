#include <vulkan/vulkan.h>

#include <array>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace {
constexpr std::array<std::uint32_t, 4> expected{17, 20, 23, 26};

void check(VkResult result, std::string_view operation) {
  if (result != VK_SUCCESS) {
    throw std::runtime_error(std::string(operation) + " failed (VkResult " +
                             std::to_string(result) + ")");
  }
}

struct Vulkan {
  VkInstance instance{};
  VkDevice device{};
  VkQueue queue{};
  VkBuffer buffer{};
  VkDeviceMemory memory{};
  VkDescriptorSetLayout descriptors{};
  VkDescriptorPool pool{};
  VkPipelineLayout layout{};
  VkShaderModule shader{};
  VkPipeline pipeline{};
  VkCommandPool commands{};
  VkFence fence{};
  bool coherent{};

  ~Vulkan() {
    if (device) {
      vkDeviceWaitIdle(device);
      vkDestroyFence(device, fence, nullptr);
      vkDestroyCommandPool(device, commands, nullptr);
      vkDestroyPipeline(device, pipeline, nullptr);
      vkDestroyShaderModule(device, shader, nullptr);
      vkDestroyPipelineLayout(device, layout, nullptr);
      vkDestroyDescriptorPool(device, pool, nullptr);
      vkDestroyDescriptorSetLayout(device, descriptors, nullptr);
      vkDestroyBuffer(device, buffer, nullptr);
      vkFreeMemory(device, memory, nullptr);
      vkDestroyDevice(device, nullptr);
    }
    if (instance) {
      vkDestroyInstance(instance, nullptr);
    }
  }

  std::uint32_t prepare() {
    VkApplicationInfo application{
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "boilerplate-vulkan-smoke",
        .apiVersion = VK_API_VERSION_1_0};
    VkInstanceCreateInfo create{.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                                .pApplicationInfo = &application};
    check(vkCreateInstance(&create, nullptr, &instance),
          "vkCreateInstance (check the host Vulkan ICD and VK_DRIVER_FILES)");
    std::uint32_t count = 0;
    check(vkEnumeratePhysicalDevices(instance, &count, nullptr),
          "Enumerate Vulkan devices");
    std::vector<VkPhysicalDevice> devices(count);
    check(vkEnumeratePhysicalDevices(instance, &count, devices.data()),
          "Read Vulkan devices");
    devices.resize(count);
    for (auto physical : devices) {
      std::uint32_t families = 0;
      vkGetPhysicalDeviceQueueFamilyProperties(physical, &families, nullptr);
      std::vector<VkQueueFamilyProperties> queues(families);
      vkGetPhysicalDeviceQueueFamilyProperties(physical, &families,
                                               queues.data());
      for (std::uint32_t family = 0; family < families; ++family) {
        if (queues[family].queueCount > 0 &&
            (queues[family].queueFlags & VK_QUEUE_COMPUTE_BIT)) {
          create_device(physical, family);
          return family;
        }
      }
    }
    throw std::runtime_error(
        "No Vulkan device with a compute queue. Check the host ICD and GPU "
        "access.");
  }

  void create_device(VkPhysicalDevice physical, std::uint32_t family) {
    VkPhysicalDeviceProperties properties{};
    vkGetPhysicalDeviceProperties(physical, &properties);
    std::cout << "Vulkan device: " << properties.deviceName << ", API "
              << VK_API_VERSION_MAJOR(properties.apiVersion) << "."
              << VK_API_VERSION_MINOR(properties.apiVersion)
              << ", driver version " << properties.driverVersion << "\n";
    float priority = 1.0f;
    VkDeviceQueueCreateInfo request{
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = family,
        .queueCount = 1,
        .pQueuePriorities = &priority};
    VkDeviceCreateInfo create{.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
                              .queueCreateInfoCount = 1,
                              .pQueueCreateInfos = &request};
    check(vkCreateDevice(physical, &create, nullptr, &device),
          "Create compute device");
    vkGetDeviceQueue(device, family, 0, &queue);

    VkBufferCreateInfo storage{.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
                               .size = sizeof(expected),
                               .usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
                               .sharingMode = VK_SHARING_MODE_EXCLUSIVE};
    check(vkCreateBuffer(device, &storage, nullptr, &buffer),
          "Create storage buffer");
    VkMemoryRequirements requirements{};
    vkGetBufferMemoryRequirements(device, buffer, &requirements);
    VkPhysicalDeviceMemoryProperties types{};
    vkGetPhysicalDeviceMemoryProperties(physical, &types);
    for (std::uint32_t i = 0; i < types.memoryTypeCount; ++i) {
      auto flags = types.memoryTypes[i].propertyFlags;
      if ((requirements.memoryTypeBits & (1u << i)) &&
          (flags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {
        coherent = (flags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) != 0;
        VkMemoryAllocateInfo allocation{
            .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .allocationSize = requirements.size,
            .memoryTypeIndex = i};
        check(vkAllocateMemory(device, &allocation, nullptr, &memory),
              "Allocate host-visible memory");
        check(vkBindBufferMemory(device, buffer, memory, 0),
              "Bind storage buffer memory");
        return;
      }
    }
    throw std::runtime_error(
        "No host-visible memory type compatible with the storage buffer.");
  }

  VkDescriptorSet create_pipeline(const std::vector<std::uint32_t>& code) {
    VkDescriptorSetLayoutBinding binding{
        .binding = 0,
        .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .descriptorCount = 1,
        .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT};
    VkDescriptorSetLayoutCreateInfo descriptor_layout{
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 1,
        .pBindings = &binding};
    check(vkCreateDescriptorSetLayout(device, &descriptor_layout, nullptr,
                                      &descriptors),
          "Create descriptor layout");
    VkDescriptorPoolSize size{.type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
                              .descriptorCount = 1};
    VkDescriptorPoolCreateInfo descriptor_pool{
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .maxSets = 1,
        .poolSizeCount = 1,
        .pPoolSizes = &size};
    check(vkCreateDescriptorPool(device, &descriptor_pool, nullptr, &pool),
          "Create descriptor pool");
    VkDescriptorSetAllocateInfo allocation{
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = pool,
        .descriptorSetCount = 1,
        .pSetLayouts = &descriptors};
    VkDescriptorSet set{};
    check(vkAllocateDescriptorSets(device, &allocation, &set),
          "Allocate descriptor set");
    VkDescriptorBufferInfo range{.buffer = buffer, .range = sizeof(expected)};
    VkWriteDescriptorSet write{
        .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
        .dstSet = set,
        .descriptorCount = 1,
        .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
        .pBufferInfo = &range};
    vkUpdateDescriptorSets(device, 1, &write, 0, nullptr);

    VkPipelineLayoutCreateInfo pipeline_layout{
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &descriptors};
    check(vkCreatePipelineLayout(device, &pipeline_layout, nullptr, &layout),
          "Create pipeline layout");
    VkShaderModuleCreateInfo module{
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.size() * sizeof(code.front()),
        .pCode = code.data()};
    check(vkCreateShaderModule(device, &module, nullptr, &shader),
          "Load SPIR-V");
    VkComputePipelineCreateInfo compute{
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage = {.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                  .stage = VK_SHADER_STAGE_COMPUTE_BIT,
                  .module = shader,
                  .pName = "main"},
        .layout = layout};
    check(vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &compute, nullptr,
                                   &pipeline),
          "Create compute pipeline");
    return set;
  }

  void dispatch(std::uint32_t family, VkDescriptorSet set) {
    VkCommandPoolCreateInfo command_pool{
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .queueFamilyIndex = family};
    check(vkCreateCommandPool(device, &command_pool, nullptr, &commands),
          "Create command pool");
    VkCommandBufferAllocateInfo allocation{
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = commands,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1};
    VkCommandBuffer command{};
    check(vkAllocateCommandBuffers(device, &allocation, &command),
          "Allocate command buffer");
    VkCommandBufferBeginInfo begin{
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT};
    check(vkBeginCommandBuffer(command, &begin), "Begin command buffer");
    vkCmdBindPipeline(command, VK_PIPELINE_BIND_POINT_COMPUTE, pipeline);
    vkCmdBindDescriptorSets(command, VK_PIPELINE_BIND_POINT_COMPUTE, layout, 0,
                            1, &set, 0, nullptr);
    vkCmdDispatch(command, 1, 1, 1);
    VkMemoryBarrier barrier{.sType = VK_STRUCTURE_TYPE_MEMORY_BARRIER,
                            .srcAccessMask = VK_ACCESS_SHADER_WRITE_BIT,
                            .dstAccessMask = VK_ACCESS_HOST_READ_BIT};
    vkCmdPipelineBarrier(command, VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                         VK_PIPELINE_STAGE_HOST_BIT, 0, 1, &barrier, 0, nullptr,
                         0, nullptr);
    check(vkEndCommandBuffer(command), "End command buffer");
    VkFenceCreateInfo create_fence{.sType =
                                       VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
    check(vkCreateFence(device, &create_fence, nullptr, &fence),
          "Create fence");
    VkSubmitInfo submit{.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
                        .commandBufferCount = 1,
                        .pCommandBuffers = &command};
    check(vkQueueSubmit(queue, 1, &submit, fence), "Submit compute dispatch");
    check(vkWaitForFences(device, 1, &fence, VK_TRUE, 10'000'000'000ull),
          "Wait for compute dispatch");
    void* mapped = nullptr;
    check(vkMapMemory(device, memory, 0, VK_WHOLE_SIZE, 0, &mapped),
          "Map result buffer");
    if (!coherent) {
      VkMappedMemoryRange range{.sType = VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE,
                                .memory = memory,
                                .size = VK_WHOLE_SIZE};
      check(vkInvalidateMappedMemoryRanges(device, 1, &range),
            "Invalidate result buffer");
    }
    std::array<std::uint32_t, expected.size()> actual{};
    std::memcpy(actual.data(), mapped, sizeof(actual));
    vkUnmapMemory(device, memory);
    if (actual != expected) {
      throw std::runtime_error("Compute shader returned unexpected values.");
    }
    std::cout << "Read back the four expected compute results.\n";
  }
};

std::vector<std::uint32_t> read_shader(const char* path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  auto bytes = static_cast<std::streamoff>(input.tellg());
  if (bytes <= 0 || bytes % sizeof(std::uint32_t) != 0) {
    throw std::runtime_error("Invalid SPIR-V file: " + std::string(path));
  }
  std::vector<std::uint32_t> code(bytes / sizeof(std::uint32_t));
  input.seekg(0);
  if (!input.read(reinterpret_cast<char*>(code.data()), bytes)) {
    throw std::runtime_error("Could not read SPIR-V file: " +
                             std::string(path));
  }
  return code;
}
}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) {
      throw std::runtime_error("Usage: vulkan_smoke --check | PATH_TO_SPIRV");
    }
    Vulkan vulkan;
    auto family = vulkan.prepare();
    if (std::string_view(argv[1]) != "--check") {
      vulkan.dispatch(family, vulkan.create_pipeline(read_shader(argv[1])));
    }
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "Vulkan smoke: " << error.what() << '\n';
    return 1;
  }
}
