#include <cstring>
#include <filesystem>
#include <iostream>
#include <stdexcept>
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
                            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR |
                                LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
#else
    handle_ = dlopen(std::filesystem::absolute(path).c_str(), RTLD_NOW | RTLD_LOCAL);
#endif
    if (!handle_) throw std::runtime_error("Cannot load plugin: " + path.string());
  }
  ~Module() {
#ifdef _WIN32
    if (handle_) FreeLibrary(handle_);
#else
    if (handle_) dlclose(handle_);
#endif
  }
  Module(const Module&) = delete;
  Module& operator=(const Module&) = delete;

  int probe() const {
#ifdef _WIN32
    const auto symbol = GetProcAddress(handle_, "sample_plugin_probe");
#else
    const auto symbol = dlsym(handle_, "sample_plugin_probe");
#endif
    if (!symbol) throw std::runtime_error("Missing sample_plugin_probe");
    using Probe = int (*)();
    Probe result{};
    static_assert(sizeof(result) == sizeof(symbol));
    std::memcpy(&result, &symbol, sizeof(result));
    return result();
  }

private:
#ifdef _WIN32
  HMODULE handle_{};
#else
  void* handle_{};
#endif
};
}  // namespace

int main(int argc, char** argv) {
  try {
    if (argc != 2) throw std::runtime_error("Usage: sample_plugin_host plugin");
    const Module module(argv[1]);
    return module.probe() == 7 ? 0 : 2;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
