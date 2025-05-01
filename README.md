# My boilerplate for cmake projects with ci/cd

[![CMake](https://img.shields.io/badge/CMake-3.26+-blue.svg)](https://cmake.org/)
[![vcpkg](https://img.shields.io/badge/vcpkg-enabled-green.svg)](https://vcpkg.io/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![](https://tokei.rs/b1/gitlab/cppshizoid/cmake_boilerplate)](https://gitlab.com/cppshizoid/cmake_boilerplate).

Structure:

```sh
```sh
├── .github/workflows
│   └── build_cmake.yml
├── build(contains generation from cmake(ninja.build) and also contains compile_commands.json
├── cmake (contains cmake scripts for project)
├── docs
|	└── CMakeLists.txt
│   └── generate_docs.py
│   └── Doxyfile.in  
├── include
│   └── *.hpp
├── lib
|   └──lib1_name (contains first library name)
|		├── cmake (contains cmake scripts for library)
|		├── include
│			└── *.hpp
|		├── src
│			└── CMakeLists.txt
|			└── *.cpp
|		├── test (contains test for lib)
|		└── CMakeLists.txt
|		└── lib_test_*.cpp(name will changes to library component name)
|   └──lib2_name (contains second library name)
|		├── cmake (contains cmake scripts for library)
|		├── include
│			└── *.hpp
|		├── src
│			└── CMakeLists.txt
|			└── *.cpp
|		├── test (contains test for lib)
|		└── CMakeLists.txt
|		└── lib_test_*.cpp(name will changes to library component name)
│── shaders(for graphics project)
│   └── *.frag/.vert
├── src
│   └── CMakeLists.txt
│   └── *.cpp
├── test
│   └── CMakeLists.txt
│   └── test_*.cpp
├── .clang-format
├── .clang-tidy
├── .gitignore
├── build_all.(ps/sh) (build all script for unix and windows)
├── CMakeLists.txt
├── CMakePresets.json
├── compile_commands.json -> build/compile_commands.json(for clangd in nvim/vsc)
├── vcpkg.json
├── Dockerfile
├── LICENSE
└── README.md
```

I use  [vcpkg](https://vcpkg.io/en/index.html) for pm(in [windows & linux](https://github.com/cppshizoidS/cmake_boilerplate/tree/vcpkg)), [cmake](https://cmake.org/) for generator files for [ninja-build](https://ninja-build.org/), [clang-format](https://clang.llvm.org/docs/ClangFormat.html) for format and [doxygen](https://www.doxygen.nl/manual/index.html) for generate docs, [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) for linting.
GTest for Unit Test and Ctest for running tests. Lcov/Gcov for test coverage.  It can be used for graphics project. 


---
This template contains everything you need:
* ready CMakeLists.txt with specific options for windows 
* cmake presets
* vcpkg.json
* cript for install all needed packages(for debain based, fedora, arch based & macos)
* github.ci/gitlab.ci
* .gitignore
* clang-format
* clang-tidy
* cmake-format
* gcov, lcov
* mold/lld linker(available for gcc/clang)
* lib build flags
* library versioning
* setuped doxygen(with graphviz)
* setuped installers for windows(NSIS) and packages for deb and rpm
* caching on ci
* basic setup for nvim zsh OMZ
* IWYU
* setuped CTest and GTest
* shader build script
* different configurations: debug, release...
* debug configs enable flags for most checks for compilers (clang/gcc and msvc)(some may confict need to pick what and when need)
* docker setup
* static analysis tools setuped
* sanizers setuped
* scritps for parallel formatting (code and cmake)
* Visual Studio cmake settings preset pick

### Build Debug

```sh
mkdir -p build/debug
cd build/debug
cmake --preset debug
cmake --build --preset build-debug
```

### Build Release:
```sh
mkdir -p build/release
cd build/release
cmake --preset release
cmake --build --preset build-release
```

### Vcpkg debug build:
```sh
cmake --preset vcpkg-debug
cmake --build --preset build-vcpkg-debug
```

### Vcpkg release  build:
```sh
cmake --preset vcpkg-release
cmake --build --preset build-vcpkg-release
```


### Build with sanitazers:

## Address sanitizer
```sh
cmake --preset debug-sanitize-address
cmake --build --preset build-debug-sanitize-address
```
## Thread sanitizer
```sh
cmake --preset debug-sanitize-thread
cmake --build --preset build-debug-sanitize-thread
```
## Undefined behavior sanitizer
```sh
cmake --preset debug-sanitize-undefined
cmake --build --preset build-debug-sanitize-undefined```
```
(specify sanitizer what you need)

### Testing

## Run all tests (release build)
```sh
ctest --preset test-all
```

## Run tests with address sanitizer
```sh
ctest --preset test-sanitize-address
```

## Run specific test suite
```sh
ctest --preset test-library1
```

## Run docs generation
```sh
cmake --build . --target docs
```
