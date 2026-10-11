cmake_minimum_required(VERSION 3.26)
project(RustSanitizerFixture LANGUAGES NONE)
include(CTest)
if(NOT TOOLKIT_DIR)
  get_filename_component(TOOLKIT_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../../cmake" ABSOLUTE)
endif()
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES rust testing)
set(_fixture_manifest "${CMAKE_CURRENT_LIST_DIR}/../Cargo.toml")
if(NOT FIXTURE_SKIP_SANITIZERS)
  boilerplate_add_rust_executable(rust_asan
    MANIFEST "${_fixture_manifest}" PACKAGE rust-fixture CARGO_TARGET fixture-bin
    FEATURES answer NO_DEFAULT_FEATURES
    RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\""
    POLICY_OPTIONS SANITIZER address)
  boilerplate_add_rust_test(rust_asan_suite TARGET rust_asan LABELS sanitizer address)
  # Named policies must lower through the same Rust policy resolver.
  boilerplate_add_rust_executable(rust_tsan
    MANIFEST "${_fixture_manifest}" PACKAGE rust-fixture CARGO_TARGET fixture-bin
    FEATURES answer NO_DEFAULT_FEATURES
    RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\""
    POLICIES tsan)
  boilerplate_add_rust_test(rust_tsan_suite TARGET rust_tsan LABELS sanitizer thread)
  # Provenance must describe the effective sanitizer, not a C++ policy.
  boilerplate_collect_target_metadata(rust_asan _asan_provenance)
  string(JOIN "\n" _asan_provenance_text ${_asan_provenance})
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/asan-metadata-$<CONFIG>.txt"
    CONTENT "${_asan_provenance_text}\n")
endif()
boilerplate_add_rust_executable(rust_plain
  MANIFEST "${_fixture_manifest}" PACKAGE rust-fixture CARGO_TARGET fixture-bin
  FEATURES answer NO_DEFAULT_FEATURES
  RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\""
  POLICY_OPTIONS SANITIZER none)
if(FIXTURE_UNSUPPORTED_SANITIZER)
  boilerplate_add_rust_executable(rust_invalid
    MANIFEST "${_fixture_manifest}" PACKAGE rust-fixture CARGO_TARGET fixture-bin
    POLICY_OPTIONS SANITIZER undefined)
endif()
if(FIXTURE_RAW_SANITIZER)
  boilerplate_add_rust_executable(rust_raw
    MANIFEST "${_fixture_manifest}" PACKAGE rust-fixture CARGO_TARGET fixture-bin
    RUSTFLAGS -Zsanitizer=address)
endif()
boilerplate_finalize_project()
