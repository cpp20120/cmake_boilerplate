cmake_minimum_required(VERSION 3.26)
project(RustFuzzFixture LANGUAGES NONE)
include(CTest)
if(NOT TOOLKIT_DIR)
  get_filename_component(TOOLKIT_DIR "${CMAKE_CURRENT_LIST_DIR}/../../../../cmake" ABSOLUTE)
endif()
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES rust fuzzing)
set(_manifest "${CMAKE_CURRENT_LIST_DIR}/project/fuzz/Cargo.toml")
if(FUZZ_INVALID_TARGET)
  set(_target absent)
else()
  set(_target scheduler)
endif()
set(_sanitizer_args)
if(FUZZ_SANITIZER_OVERRIDE)
  list(APPEND _sanitizer_args SANITIZER "${FUZZ_SANITIZER_OVERRIDE}")
endif()
boilerplate_add_rust_fuzzer(scheduler_fuzz
  MANIFEST "${_manifest}"
  FUZZ_TARGET "${_target}"
  SEED_CORPUS "${CMAKE_CURRENT_LIST_DIR}/project/fuzz/seeds"
  DICTIONARY "${CMAKE_CURRENT_LIST_DIR}/project/fuzz/dictionary.txt"
  FEATURES scheduler test_feature
  NO_DEFAULT_FEATURES
  RUN_SECONDS 2 TIMEOUT 3 MAX_LEN 128
  ${_sanitizer_args})
# A second producer for the same Rust fuzz target must never reuse an
# incompatible instrumentation build directory.
boilerplate_add_rust_fuzzer(scheduler_fuzz_plain
  MANIFEST "${_manifest}" FUZZ_TARGET scheduler
  SANITIZER none NO_SMOKE RUN_SECONDS 1)
boilerplate_finalize_project()
