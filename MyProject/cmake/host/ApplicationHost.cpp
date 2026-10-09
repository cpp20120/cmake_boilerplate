#include <boilerplate/application_api.hpp>
#include <boilerplate_host_config.hpp>

#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#ifdef _WIN32
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0602
#endif
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#ifdef BOILERPLATE_HOST_GUI
#include <shellapi.h>
#endif
#elif defined(__APPLE__)
#include <dlfcn.h>
#include <mach-o/dyld.h>
#else
#include <dlfcn.h>
#include <unistd.h>
#endif

namespace {
std::filesystem::path executable_path(char* argv0) {
#ifdef _WIN32
  std::wstring value(32768, L'\0');
  const auto size = GetModuleFileNameW(nullptr, value.data(), static_cast<DWORD>(value.size()));
  if (size != 0 && size < value.size()) {
    value.resize(size);
    return std::filesystem::path(value);
  }
#elif defined(__APPLE__)
  std::uint32_t size = 0;
  _NSGetExecutablePath(nullptr, &size);
  std::vector<char> value(size + 1, '\0');
  if (_NSGetExecutablePath(value.data(), &size) == 0) {
    return std::filesystem::weakly_canonical(value.data());
  }
#else
  std::vector<char> value(4096, '\0');
  const auto size = readlink("/proc/self/exe", value.data(), value.size() - 1);
  if (size > 0) {
    value[static_cast<std::size_t>(size)] = '\0';
    return std::filesystem::path(value.data());
  }
#endif
  return std::filesystem::absolute(argv0 ? argv0 : BOILERPLATE_APPLICATION_NAME);
}

std::filesystem::path locate_application(char* argv0) {
  if (const char* override_path = std::getenv("BOILERPLATE_APPLICATION_MODULE")) {
    if (*override_path) return std::filesystem::absolute(override_path);
  }

  const auto exe_dir = executable_path(argv0).parent_path();
  const auto sibling = exe_dir / BOILERPLATE_APPLICATION_MODULE_FILE;
  if (std::filesystem::exists(sibling)) return sibling;

  const auto installed = (exe_dir / BOILERPLATE_APPLICATION_PRIVATE_DIR /
                          BOILERPLATE_APPLICATION_MODULE_FILE).lexically_normal();
  if (std::filesystem::exists(installed)) return installed;

  const std::filesystem::path build_module = BOILERPLATE_APPLICATION_BUILD_MODULE;
  if (std::filesystem::exists(build_module)) return build_module;

  throw std::runtime_error(
      std::string("Cannot locate application module '") +
      BOILERPLATE_APPLICATION_MODULE_FILE + "' for " + BOILERPLATE_APPLICATION_NAME);
}

class Module {
public:
  explicit Module(const std::filesystem::path& path) {
#ifdef _WIN32
    SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS | LOAD_LIBRARY_SEARCH_USER_DIRS);
    cookie_ = AddDllDirectory(path.parent_path().c_str());
    handle_ = LoadLibraryExW(path.c_str(), nullptr,
                             LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR |
                             LOAD_LIBRARY_SEARCH_DEFAULT_DIRS |
                             LOAD_LIBRARY_SEARCH_USER_DIRS);
    if (!handle_) throw std::runtime_error("Cannot load application module: " + path.string());
#else
    handle_ = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (!handle_) {
      const char* error = dlerror();
      throw std::runtime_error(std::string("Cannot load application module: ") +
                               path.string() + (error ? ": " + std::string(error) : ""));
    }
#endif
  }
  Module(const Module&) = delete;
  Module& operator=(const Module&) = delete;
  ~Module() {
#ifdef _WIN32
    if (handle_) FreeLibrary(handle_);
    if (cookie_) RemoveDllDirectory(cookie_);
#else
    if (handle_) dlclose(handle_);
#endif
  }

  BoilerplateApplicationQuery query() const {
#ifdef _WIN32
    const auto symbol = GetProcAddress(handle_, boilerplate_application_query_symbol);
#else
    const auto symbol = dlsym(handle_, boilerplate_application_query_symbol);
#endif
    if (!symbol) throw std::runtime_error("Application module is missing boilerplate_application_query");
    BoilerplateApplicationQuery result{};
    static_assert(sizeof(result) == sizeof(symbol));
    std::memcpy(&result, &symbol, sizeof(result));
    return result;
  }

private:
#ifdef _WIN32
  HMODULE handle_{};
  DLL_DIRECTORY_COOKIE cookie_{};
#else
  void* handle_{};
#endif
};
}  // namespace

int boilerplate_host_main(int argc, char** argv) {
  try {
    const auto path = locate_application(argc > 0 ? argv[0] : nullptr);
    const Module module(path);
    const auto* api = module.query()(boilerplate_application_abi_version,
                                     sizeof(BoilerplateApplicationApi));
    if (!api || api->version != boilerplate_application_abi_version ||
        api->size != sizeof(BoilerplateApplicationApi) || !api->run) {
      throw std::runtime_error("Incompatible application bootstrap ABI");
    }
    return api->run(argc, argv);
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}

#if defined(_WIN32) && defined(BOILERPLATE_HOST_GUI)
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argc = 0;
  LPWSTR* wide_argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (!wide_argv) return boilerplate_host_main(0, nullptr);

  std::vector<std::string> storage;
  storage.reserve(static_cast<std::size_t>(argc));
  for (int index = 0; index < argc; ++index) {
    const int bytes = WideCharToMultiByte(CP_UTF8, 0, wide_argv[index], -1,
                                          nullptr, 0, nullptr, nullptr);
    std::string value(static_cast<std::size_t>(bytes), '\0');
    if (bytes > 0) {
      WideCharToMultiByte(CP_UTF8, 0, wide_argv[index], -1, value.data(), bytes,
                          nullptr, nullptr);
      value.pop_back();
    }
    storage.push_back(std::move(value));
  }
  LocalFree(wide_argv);

  std::vector<char*> argv;
  argv.reserve(storage.size());
  for (auto& value : storage) argv.push_back(value.data());
  return boilerplate_host_main(argc, argv.data());
}
#else
int main(int argc, char** argv) {
  return boilerplate_host_main(argc, argv);
}
#endif
