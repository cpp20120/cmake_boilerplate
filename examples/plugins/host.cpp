#include "api.hpp"
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace {
class Module {
public:
  explicit Module(const std::filesystem::path& path) {
#ifdef _WIN32
    handle_ = LoadLibraryExW(std::filesystem::absolute(path).c_str(), nullptr,
                            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
#else
    handle_ = dlopen(std::filesystem::absolute(path).c_str(), RTLD_NOW | RTLD_LOCAL);
#endif
    if (!handle_) throw std::runtime_error("Cannot load plugin: " + path.string());
  }
  Module(const Module&) = delete;
  Module& operator=(const Module&) = delete;
  ~Module() {
#ifdef _WIN32
    FreeLibrary(handle_);
#else
    dlclose(handle_);
#endif
  }
  ExamplePluginQuery query() const {
#ifdef _WIN32
    const auto symbol = GetProcAddress(handle_, "example_plugin_query");
#else
    const auto symbol = dlsym(handle_, "example_plugin_query");
#endif
    if (!symbol) throw std::runtime_error("Missing plugin entry point");
    ExamplePluginQuery result{};
    static_assert(sizeof(result) == sizeof(symbol));
    std::memcpy(&result, &symbol, sizeof(result));
    return result;
  }
private:
#ifdef _WIN32
  HMODULE handle_{};
#else
  void* handle_{};
#endif
};
}

int main(int argc, char** argv) {
  try {
    if (argc < 2 || argc > 4) throw std::runtime_error("Usage: plugin_host plugin [replacement-plugin] [resource-file]");
    std::int32_t state = 40;
    for (int generation = 0; generation < 2; ++generation) {
      // Host state survives reload. All calls finish and all module pointers
      // leave scope before unload. A production host must also join workers.
      const Module module(argv[generation == 1 && argc >= 3 ? 2 : 1]);
      const auto* api = module.query()(example_plugin_version, sizeof(ExamplePluginApi));
      if (!api || api->version != example_plugin_version || api->size != sizeof(ExamplePluginApi) || !api->step)
        throw std::runtime_error("Incompatible plugin ABI");
      state = api->step(state);
    }
    if (state != 42) throw std::runtime_error("Plugin state did not survive reload");
    if (argc == 4) {
      std::ifstream resource(argv[3]);
      std::string value;
      std::getline(resource, value);
      if (value != "asset-ok") throw std::runtime_error("Missing or invalid installed resource");
    }
    std::cout << "Plugin reload OK: state=" << state << '\n';
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
