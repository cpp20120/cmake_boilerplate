```sh
```sh
├── .github/workflows
│   └── build_cmake.yml
├── build(contains generation from cmake(ninja.build) and also contains compile_commands.json
├── cmake (contains cmake scripts for project)
├── docs
│   └── CMakeLists.txt
│   └── Doxyfile.in  
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
