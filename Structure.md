```sh
├── .github/workflows
│   └── build_cmake.yml
├── build(contains generation from cmake(ninja.build) and also contains compile_commands.json
├── docs
│   └── CMakeLists.txt
│   └── Doxyfile.in  
├── include
│   └── *.hpp
├── lib
|   ├── include
│       └── *.hpp
|   ├── src
│       └── CMakeLists.txt
|       └── *.cpp
|   └── CMakeLists.txt
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
├── CMakeLists.txt
├── CMakePresets.json
├── compile_commands.json -> build/compile_commands.json(for clangd in nvim/vsc)
├── conanfile.txt
├── Dockerfile
├── LICENSE
└── README.md
```
