cmake_minimum_required(VERSION 3.26)
project(RustFixture LANGUAGES CXX)
include(CTest)
if(NOT TOOLKIT_DIR)
  get_filename_component(TOOLKIT_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../cmake" ABSOLUTE)
endif()
include("${TOOLKIT_DIR}/Boilerplate.cmake")
option(FIXTURE_RUST "Exercise the optional Rust backend" ON)
set(_caps testing)
if(FIXTURE_RUST)
  list(APPEND _caps rust)
endif()
boilerplate_project(CAPABILITIES ${_caps})
boilerplate_add_executable(cpp_probe SOURCES main.cpp POLICIES minimal)
boilerplate_register_check(cpp_probe cpp_probe)
boilerplate_add_executable(cpp_bench SOURCES benchmark.cpp POLICIES minimal)
boilerplate_add_harness(cpp_harness TARGET cpp_bench ARGS 4
  ROUNDS 2 WARMUP_RUNS 1 METRICS items INVARIANTS checksum)
boilerplate_add_scenario(cpp_scenario TARGET cpp_bench ARGS 4 REPEATS 2 WARMUP 1)
# Baseline values/keys from the pre-backend C++ reports, independent of the adapter.
set(_expected)
boilerplate_append_setting(_expected EXPECTED_CXX_COMPILER "${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}")
boilerplate_append_setting(_expected EXPECTED_CXX_SCENARIO_COMPILER "${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
boilerplate_append_setting(_expected EXPECTED_CXX_PATH "${CMAKE_CXX_COMPILER}")
boilerplate_append_setting(_expected EXPECTED_CXX_PROFILE "${BOILERPLATE_PROFILE}")
if(DEFINED BOILERPLATE_ALLOCATOR)
  boilerplate_append_setting(_expected EXPECTED_CXX_ALLOCATOR "${BOILERPLATE_ALLOCATOR}")
endif()
set(_keys CXX_STANDARD SANITIZER CFI CFI_DIAGNOSTICS WINDOWS_CFG LTO_MODE PGO_MODE ENABLE_NATIVE
  ENABLE_NO_SEMANTIC_INTERPOSITION ENABLE_GC_SECTIONS ENABLE_NO_PLT USE_LLD ENABLE_ICF FRAME_POINTERS REPRODUCIBLE HARDENING COVERAGE)
boilerplate_append_setting(_expected EXPECTED_CXX_KEYS "${_keys}")
foreach(_key IN LISTS _keys)
  boilerplate_get_target_setting(cpp_bench ${_key} _value)
  boilerplate_append_setting(_expected EXPECTED_${_key} "${_value}")
endforeach()
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/expected-cxx.cmake" "${_expected}")
if(FIXTURE_RUST)
  add_custom_target(rust_prerequisite
    COMMAND "${CMAKE_COMMAND}" -E touch "${CMAKE_CURRENT_BINARY_DIR}/prerequisite" VERBATIM)
  boilerplate_add_rust_executable(rust_bin MANIFEST Cargo.toml CARGO_TARGET fixture-bin
    PACKAGE rust-fixture FEATURES answer NO_DEFAULT_FEATURES LOCKED OFFLINE
    RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\"" DEPENDS rust_prerequisite)
  boilerplate_add_rust_executable(rust_example MANIFEST Cargo.toml KIND example CARGO_TARGET hello
    PACKAGE rust-fixture FEATURES answer NO_DEFAULT_FEATURES LOCKED OFFLINE
    RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\"" EXCLUDE_FROM_ALL)
  foreach(_target IN ITEMS rust_bin rust_example)
    get_target_property(_type ${_target} TYPE)
    get_target_property(_imported ${_target} IMPORTED)
    get_target_property(_policies ${_target} BOILERPLATE_POLICY_CONFIGURED)
    if(NOT _type STREQUAL "EXECUTABLE" OR NOT _imported OR _policies)
      message(FATAL_ERROR "Cargo target is not a policy-free imported executable")
    endif()
  endforeach()
  # No explicit DEPENDS: TARGET_FILE alone must follow the import's build edge.
  add_custom_target(run_rust
    COMMAND "$<TARGET_FILE:rust_bin>" COMMAND "$<TARGET_FILE:rust_example>" VERBATIM)
  # Exercise a file dependency as well as a target dependency (Ninja byproducts).
  add_custom_command(OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/copied-$<CONFIG>${CMAKE_EXECUTABLE_SUFFIX}"
    COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:rust_bin>"
      "${CMAKE_CURRENT_BINARY_DIR}/copied-$<CONFIG>${CMAKE_EXECUTABLE_SUFFIX}"
    DEPENDS "$<TARGET_FILE:rust_bin>" VERBATIM)
  add_custom_target(copy_rust DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/copied-$<CONFIG>${CMAKE_EXECUTABLE_SUFFIX}")
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/binary-$<CONFIG>.txt" CONTENT "$<TARGET_FILE:rust_bin>")
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/example-$<CONFIG>.txt" CONTENT "$<TARGET_FILE:rust_example>")
  boilerplate_register_check(rust_binary rust_bin LABELS rust)
  boilerplate_add_rust_test(rust_suite TARGET rust_bin LABELS fixture TEST_ARGS --nocapture)

  boilerplate_add_rust_executable(rust_bench MANIFEST Cargo.toml CARGO_TARGET fixture-benchmark
    PACKAGE rust-fixture FEATURES answer benchmark NO_DEFAULT_FEATURES LOCKED OFFLINE
    RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\"" DEPENDS rust_bench_input EXCLUDE_FROM_ALL)
  get_target_property(_bench_dir rust_bench BOILERPLATE_RUST_TARGET_DIR)
  add_custom_target(rust_bench_input
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${_bench_dir}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/bench_input.rs" "${_bench_dir}/bench_input.rs"
    BYPRODUCTS "${_bench_dir}/bench_input.rs" VERBATIM)
  boilerplate_add_harness(rust_harness TARGET rust_bench CASES benchmark_cases.json CASE_GROUP valid
    ROUNDS 2 WARMUP_RUNS 1 RANDOMIZE METRICS items INVARIANTS checksum)
  boilerplate_add_harness(rust_json TARGET rust_bench ARGS json 4 PARSER json
    ROUNDS 2 WARMUP_RUNS 1 METRICS items INVARIANTS checksum)
  boilerplate_add_harness(rust_none TARGET rust_bench ARGS invalid PARSER none)
  boilerplate_add_harness(rust_invalid TARGET rust_bench CASES benchmark_cases.json CASE_GROUP invalid
    METRICS items INVARIANTS checksum)
  boilerplate_add_harness(rust_unstable TARGET rust_bench
    ARGS unstable 4 "${CMAKE_CURRENT_BINARY_DIR}/unstable-$<CONFIG>.txt"
    ROUNDS 2 INVARIANTS checksum)
  boilerplate_add_harness(rust_failed TARGET rust_bench ARGS fail PARSER none)
  boilerplate_add_scenario(rust_first TARGET rust_bench GROUP rust_benchmarks ARGS json 4
    REPEATS 2 WARMUP 1 SMOKE SMOKE_ARGS json 2)
  boilerplate_add_scenario(rust_second TARGET rust_bench GROUP rust_benchmarks ARGS json 8
    REPEATS 1 WARMUP 0)
  if(FIXTURE_RUST_PGO)
    boilerplate_add_scenario(rust_pgo TARGET rust_bench PGO)
  endif()
  # Model the execution gate without pretending stage 1 supports Rust cross builds.
  set(CMAKE_CROSSCOMPILING TRUE)
  boilerplate_add_harness(rust_blocked TARGET rust_bench PARSER none)
  boilerplate_add_scenario(rust_blocked_scenario TARGET rust_bench SMOKE)
  set_property(TARGET rust_bench PROPERTY CROSSCOMPILING_EMULATOR "${CMAKE_COMMAND};-E;env;FIXTURE_EMULATED=1")
  boilerplate_add_harness(rust_emulated TARGET rust_bench ARGS json 4 METRICS items)
  boilerplate_add_scenario(rust_emulated_scenario TARGET rust_bench ARGS json 4 REPEATS 1 WARMUP 0)
  set_property(TARGET rust_bench PROPERTY CROSSCOMPILING_EMULATOR "")
  set(CMAKE_CROSSCOMPILING FALSE)
  get_target_property(_policies rust_bench BOILERPLATE_POLICY_CONFIGURED)
  if(_policies)
    message(FATAL_ERROR "Benchmark registration applied C++ policies to Rust")
  endif()
  file(GENERATE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/bench-$<CONFIG>.txt" CONTENT "$<TARGET_FILE:rust_bench>")

  if(FIXTURE_PROFILE_VARIANTS)
    # Intentionally two Cargo invocations for the SAME package and bin, with
    # independent policies and artifacts. Tests verify both survive concurrently.
    boilerplate_define_policy(rust-fast
      RUST_OPT_LEVEL 3 LTO_MODE thin RUST_CODEGEN_UNITS 1 FRAME_POINTERS ON)
    boilerplate_add_rust_executable(rust_variant_fast
      MANIFEST Cargo.toml CARGO_TARGET fixture-bin PACKAGE rust-fixture
      FEATURES answer NO_DEFAULT_FEATURES LOCKED OFFLINE EXCLUDE_FROM_ALL
      RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\""
      POLICIES rust-fast)
    boilerplate_add_rust_executable(rust_variant_small
      MANIFEST Cargo.toml CARGO_TARGET fixture-bin PACKAGE rust-fixture
      FEATURES answer NO_DEFAULT_FEATURES LOCKED OFFLINE EXCLUDE_FROM_ALL
      RUSTFLAGS --cfg "cmake_fixture=\"value with spaces\""
      POLICY_OPTIONS RUST_OPT_LEVEL z RUST_CODEGEN_UNITS 8 LTO_MODE off)
    add_custom_target(run_rust_variants
      COMMAND "$<TARGET_FILE:rust_variant_fast>"
      COMMAND "$<TARGET_FILE:rust_variant_small>"
      DEPENDS rust_variant_fast rust_variant_small VERBATIM)
    if(FIXTURE_BAD_RUST_POLICY)
      boilerplate_add_rust_executable(rust_bad_policy MANIFEST Cargo.toml
        CARGO_TARGET fixture-bin PACKAGE rust-fixture
        POLICY_OPTIONS UNITY_BUILD ON)
    endif()
    if(FIXTURE_BAD_RUST_PROFILE)
      boilerplate_add_rust_executable(rust_bad_profile MANIFEST Cargo.toml
        CARGO_TARGET fixture-bin PACKAGE rust-fixture
        POLICY_OPTIONS RUST_CARGO_PROFILE test)
    endif()
  endif()
  if(FIXTURE_BAD_POLICY)
    boilerplate_apply_target_policy(rust_bin POLICIES minimal)
  endif()
endif()
boilerplate_finalize_project()
if(FIXTURE_LATE_TARGET)
  boilerplate_add_rust_executable(late MANIFEST Cargo.toml)
endif()
