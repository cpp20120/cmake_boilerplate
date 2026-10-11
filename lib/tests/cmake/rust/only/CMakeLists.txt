cmake_minimum_required(VERSION 3.26)
project(RustOnly LANGUAGES NONE)
include(CTest)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES rust testing)
boilerplate_add_rust_executable(rust_only
  MANIFEST ../Cargo.toml PACKAGE rust-fixture CARGO_TARGET fixture-bin
  FEATURES answer NO_DEFAULT_FEATURES LOCKED OFFLINE
  RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\"")
boilerplate_add_rust_test(rust_only_tests TARGET rust_only)
boilerplate_finalize_project()
