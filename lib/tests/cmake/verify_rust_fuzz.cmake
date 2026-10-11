cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<scratch root>")
endif()
if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL Linux)
  message(STATUS "Rust cargo-fuzz regression is Linux-only; skipping")
  return()
endif()
if(NOT CHECK_GENERATOR)
  set(CHECK_GENERATOR Ninja)
endif()
set(_src "${CMAKE_CURRENT_LIST_DIR}/rust/fuzz")
get_filename_component(_toolkit "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
file(REMOVE_RECURSE "${CHECK_BINARY}")
file(MAKE_DIRECTORY "${CHECK_BINARY}/bin" "${CHECK_BINARY}/sysroot/lib/rustlib/x86_64-unknown-linux-gnu")
set(FAKE_SYSROOT "${CHECK_BINARY}/sysroot")
set(TRIPLE "x86_64-unknown-linux-gnu")
set(CHANNEL "-nightly")
set(FAKE_FUZZ_BIN "${CHECK_BINARY}/bin/cargo-fuzz")
configure_file("${_src}/fake-cargo.sh.in" "${CHECK_BINARY}/bin/cargo" @ONLY)
configure_file("${_src}/fake-rustc.sh.in" "${CHECK_BINARY}/bin/rustc" @ONLY)
configure_file("${_src}/fake-cargo-fuzz.sh.in" "${FAKE_FUZZ_BIN}" @ONLY)
file(CHMOD "${CHECK_BINARY}/bin/cargo" "${CHECK_BINARY}/bin/rustc" "${FAKE_FUZZ_BIN}"
  PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
file(MAKE_DIRECTORY "${FAKE_SYSROOT}/lib/rustlib/src/rust/library")
file(WRITE "${FAKE_SYSROOT}/lib/rustlib/src/rust/library/Cargo.toml" "[workspace]\n")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _ret OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(NOT _ret STREQUAL "0")
    message(FATAL_ERROR "cargo-fuzz regression failed: ${ARGN}\n${_out}\n${_err}")
  endif()
endfunction()
function(reject expected)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _ret OUTPUT_VARIABLE _out ERROR_VARIABLE _err)
  if(_ret STREQUAL "0" OR NOT "${_out}\n${_err}" MATCHES "${expected}")
    message(FATAL_ERROR "cargo-fuzz expected '${expected}' rejection: ${ARGN}\n${_out}\n${_err}")
  endif()
endfunction()
function(configure_case dir)
  # Positive launcher-injection tests must start with no native compiler
  # overrides, irrespective of what this verifier inherited from the shell.
  # Otherwise an inherited CC can disappear at build time and correctly trip
  # fingerprint validation, obscuring the CXX-added behavior under test.
  run("${CMAKE_COMMAND}" -E env
    --unset=CC --unset=CXX --unset=AR
    --unset=CFLAGS --unset=CXXFLAGS --unset=LDFLAGS
    "${CMAKE_COMMAND}" -S "${_src}" -B "${CHECK_BINARY}/${dir}"
    -G "${CHECK_GENERATOR}" "-DTOOLKIT_DIR=${_toolkit}"
    "-DBOILERPLATE_RUST_CARGO=${CHECK_BINARY}/bin/cargo"
    "-DBOILERPLATE_RUST_RUSTC=${CHECK_BINARY}/bin/rustc"
    "-DBOILERPLATE_RUST_CARGO_FUZZ=${FAKE_FUZZ_BIN}"
    -DCMAKE_BUILD_TYPE=Debug ${ARGN})
endfunction()
configure_case("valid with spaces")
set(_build "${CHECK_BINARY}/valid with spaces")
file(READ "${_build}/rust-fuzz/scheduler_fuzz/Debug/fuzz.cmake" _config)
if(NOT _config MATCHES "FUZZ_SANITIZER.*address" OR NOT _config MATCHES "FUZZ_CONFIG.*Debug")
  message(FATAL_ERROR "cargo-fuzz configuration lacks sanitizer/profile")
endif()
file(STRINGS "${_build}/rust-fuzz/scheduler_fuzz/Debug/fuzz.cmake" _td REGEX "^set\\(FUZZ_TARGET_DIR ")
if(NOT _td MATCHES "^set\\(FUZZ_TARGET_DIR \\[==\\[(.*)\\]==\\]\\)$")
  message(FATAL_ERROR "Cannot parse cargo-fuzz target directory: ${_td}")
endif()
set(_variant_dir "${CMAKE_MATCH_1}")
file(READ "${_build}/rust-fuzz/scheduler_fuzz_plain/Debug/fuzz.cmake" _plain_config)
file(STRINGS "${_build}/rust-fuzz/scheduler_fuzz_plain/Debug/fuzz.cmake" _plain_dir REGEX "^set\\(FUZZ_TARGET_DIR ")
if(_td STREQUAL _plain_dir)
  message(FATAL_ERROR "Sanitized and unsanitized cargo-fuzz targets share a build variant")
endif()
run("${CMAKE_COMMAND}" -E env "CXX=/fake/injected/by/launcher"
  "${CMAKE_COMMAND}" --build "${_build}" --config Debug --target fuzz_scheduler_fuzz scheduler_fuzz_plain_cargo_fuzz_build)
file(READ "${_variant_dir}/invocations.log" _log)
foreach(_expected IN ITEMS "mode=build" "mode=run" "--fuzz-dir=" "--target-dir=" "--build-std"
    "--sanitizer=address" "--dev" "-max_total_time=2" "-timeout=3" "-artifact_prefix="
    "-max_len=128" "-dict=" "--features=scheduler,test_feature" "--no-default-features")
  if(NOT _log MATCHES "${_expected}")
    message(FATAL_ERROR "cargo-fuzz missing '${_expected}' in invocation:\n${_log}")
  endif()
endforeach()
set(_mutable "${_build}/rust-fuzz/scheduler_fuzz/corpus/seed-one")
if(NOT EXISTS "${_mutable}")
  message(FATAL_ERROR "cargo-fuzz seed file not copied to mutable corpus")
endif()
file(WRITE "${_mutable}" "mutated seed")
run("${CMAKE_COMMAND}" --build "${_build}" --target fuzz_scheduler_fuzz)
file(READ "${_mutable}" _after)
if(NOT _after STREQUAL "mutated seed")
  message(FATAL_ERROR "cargo-fuzz overwrote mutable corpus input with seed")
endif()
run("${CMAKE_CTEST_COMMAND}" --test-dir "${_build}" -C Debug -R "scheduler_fuzz_smoke" --output-on-failure)
run("${CMAKE_COMMAND}" --build "${_build}" --target boilerplate_fuzzers)
file(READ "${_variant_dir}/invocations.log" _log)
if(NOT _log MATCHES "-runs=1")
  message(FATAL_ERROR "cargo-fuzz smoke was not bounded")
endif()
reject("BOILERPLATE_FUZZ_REPLAY_INPUT" "${CMAKE_COMMAND}" --build "${_build}" --target replay_scheduler_fuzz)
set(_crash "${_build}/rust-fuzz/scheduler_fuzz/artifacts/crash-foo")
file(WRITE "${_crash}" "bad-input")
run("${CMAKE_COMMAND}" -E env "BOILERPLATE_FUZZ_REPLAY_INPUT=${_crash}"
  "${CMAKE_COMMAND}" --build "${_build}" --target replay_scheduler_fuzz)
file(READ "${_variant_dir}/invocations.log" _log)
if(NOT _log MATCHES "${_crash}")
  message(FATAL_ERROR "cargo-fuzz replay input not forwarded")
endif()
reject("RUSTFLAGS" "${CMAKE_COMMAND}" -E env "RUSTFLAGS=-Copt-level=1"
  "${CMAKE_COMMAND}" --build "${_build}" --target scheduler_fuzz_cargo_fuzz_build)
# When CC/CXX were explicitly present during producer registration, changing
# or removing either must still be rejected by the fingerprint. Keep the other
# compiler variable fixed so each rejection tests only the intended key.
set(_configured_cc "/fake/configured/cc")
set(_changed_cc "/fake/changed/cc")
set(_configured_cxx "/fake/configured/cxx")
set(_changed_cxx "/fake/changed/cxx")
set(_native_build "${CHECK_BINARY}/configured-native")
set(_native_env --unset=AR --unset=CFLAGS --unset=CXXFLAGS --unset=LDFLAGS)
run("${CMAKE_COMMAND}" -E env ${_native_env}
  "CC=${_configured_cc}" "CXX=${_configured_cxx}"
  "${CMAKE_COMMAND}" -S "${_src}" -B "${_native_build}"
  -G "${CHECK_GENERATOR}" "-DTOOLKIT_DIR=${_toolkit}"
  "-DBOILERPLATE_RUST_CARGO=${CHECK_BINARY}/bin/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${CHECK_BINARY}/bin/rustc"
  "-DBOILERPLATE_RUST_CARGO_FUZZ=${FAKE_FUZZ_BIN}"
  -DCMAKE_BUILD_TYPE=Debug)
# Check the fingerprint against the actual RunFuzz entry point. The other
# tests exercise the Ninja/CTest targets; this case isolates the validator so
# the host's native compiler environment does not depend on build-tool
# environment forwarding. Never weaken the underlying fingerprint invariant.
set(_native_runner "${_toolkit}/rust/RunFuzz.cmake")
set(_native_config "${_native_build}/rust-fuzz/scheduler_fuzz/Debug/fuzz.cmake")
set(_native_command "${CMAKE_COMMAND}"
  "-DFUZZ_CONFIG_FILE=${_native_config}"
  -DFUZZ_MODE=build -P "${_native_runner}")
run("${CMAKE_COMMAND}" -E env ${_native_env}
  "CC=${_configured_cc}" "CXX=${_configured_cxx}"
  ${_native_command})
reject("CXX[^)]*changed" "${CMAKE_COMMAND}" -E env ${_native_env}
  "CC=${_configured_cc}" "CXX=${_changed_cxx}"
  ${_native_command})
reject("CXX[^)]*unset" "${CMAKE_COMMAND}" -E env ${_native_env}
  --unset=CXX "CC=${_configured_cc}"
  ${_native_command})
reject("CC[^)]*changed" "${CMAKE_COMMAND}" -E env ${_native_env}
  "CC=${_changed_cc}" "CXX=${_configured_cxx}"
  ${_native_command})
reject("CC[^)]*unset" "${CMAKE_COMMAND}" -E env ${_native_env}
  --unset=CC "CXX=${_configured_cxx}"
  ${_native_command})
# Invalid registrations and build capabilities must fail eagerly.
reject("fuzz target missing" "${CMAKE_COMMAND}" -S "${_src}" -B "${CHECK_BINARY}/invalid-target"
  -G Ninja "-DTOOLKIT_DIR=${_toolkit}" -DCMAKE_BUILD_TYPE=Debug
  "-DBOILERPLATE_RUST_CARGO=${CHECK_BINARY}/bin/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${CHECK_BINARY}/bin/rustc"
  "-DBOILERPLATE_RUST_CARGO_FUZZ=${FAKE_FUZZ_BIN}" -DFUZZ_INVALID_TARGET=ON)
configure_case(none -DFUZZ_SANITIZER_OVERRIDE=none)
file(READ "${CHECK_BINARY}/none/rust-fuzz/scheduler_fuzz/Debug/fuzz.cmake" _none)
if(NOT _none MATCHES "FUZZ_SANITIZER.*none")
  message(FATAL_ERROR "Explicit Rust cargo-fuzz SANITIZER none not propagated")
endif()
if(CHECK_GENERATOR STREQUAL "Ninja Multi-Config")
  run("${CMAKE_COMMAND}" --build "${_build}" --config Release --target scheduler_fuzz_cargo_fuzz_build)
  file(READ "${_build}/rust-fuzz/scheduler_fuzz/Release/fuzz.cmake" _release)
  if(NOT _release MATCHES "FUZZ_CONFIG.*Release")
    message(FATAL_ERROR "Release fuzz config not generated")
  endif()
endif()
# Negative toolchain, instrumentation and tool discovery cases.
set(CHANNEL "")
configure_file("${_src}/fake-cargo.sh.in" "${CHECK_BINARY}/bin/cargo-stable" @ONLY)
configure_file("${_src}/fake-rustc.sh.in" "${CHECK_BINARY}/bin/rustc-stable" @ONLY)
file(CHMOD "${CHECK_BINARY}/bin/cargo-stable" "${CHECK_BINARY}/bin/rustc-stable"
  PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
# Select matching stable tools from a separate installation directory.
file(MAKE_DIRECTORY "${CHECK_BINARY}/stable")
file(COPY_FILE "${CHECK_BINARY}/bin/cargo-stable" "${CHECK_BINARY}/stable/cargo")
file(COPY_FILE "${CHECK_BINARY}/bin/rustc-stable" "${CHECK_BINARY}/stable/rustc")
reject("requires a matching nightly" "${CMAKE_COMMAND}" -S "${_src}"
  -B "${CHECK_BINARY}/stable-case" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${CHECK_BINARY}/stable/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${CHECK_BINARY}/stable/rustc"
  "-DBOILERPLATE_RUST_CARGO_FUZZ=${FAKE_FUZZ_BIN}")
reject("supports SANITIZER address or none" "${CMAKE_COMMAND}" -S "${_src}"
  -B "${CHECK_BINARY}/unsupported-san" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${CHECK_BINARY}/bin/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${CHECK_BINARY}/bin/rustc"
  "-DBOILERPLATE_RUST_CARGO_FUZZ=${FAKE_FUZZ_BIN}" -DFUZZ_SANITIZER_OVERRIDE=thread)
# The sysroot component is checked at configure time (before any Cargo command).
file(RENAME "${FAKE_SYSROOT}/lib/rustlib/src/rust/library/Cargo.toml"
  "${FAKE_SYSROOT}/lib/rustlib/src/rust/library/Cargo.toml.bak")
reject("requires rust-src" "${CMAKE_COMMAND}" -S "${_src}"
  -B "${CHECK_BINARY}/missing-src" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${CHECK_BINARY}/bin/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${CHECK_BINARY}/bin/rustc"
  "-DBOILERPLATE_RUST_CARGO_FUZZ=${FAKE_FUZZ_BIN}")
file(RENAME "${FAKE_SYSROOT}/lib/rustlib/src/rust/library/Cargo.toml.bak"
  "${FAKE_SYSROOT}/lib/rustlib/src/rust/library/Cargo.toml")
# cargo-fuzz launches its own unqualified `cargo` subprocess. A package
# manager can install cargo-fuzz beside stable Cargo while the selected nightly
# toolchain lives elsewhere. The nested command must resolve nightly.
set(_plugin_dir "${CHECK_BINARY}/plugin-with-stable-cargo")
set(_nightly_bin "${CHECK_BINARY}/selected-nightly-bin")
file(MAKE_DIRECTORY "${_plugin_dir}" "${_nightly_bin}")
file(WRITE "${_plugin_dir}/cargo"
  "#!/bin/sh\nprintf '%s\\n' stable\n")
file(WRITE "${_plugin_dir}/cargo-fuzz"
  "#!/bin/sh\nif [ \"$(cargo --version)\" != nightly ]; then\n  echo 'cargo-fuzz resolved stable Cargo instead of selected nightly' >&2\n  exit 71\nfi\nexit 0\n")
file(WRITE "${_nightly_bin}/cargo"
  "#!/bin/sh\nif [ \"$1\" = fuzz ]; then\n  shift\n  exec \"${_plugin_dir}/cargo-fuzz\" \"$@\"\nfi\nif [ \"$1\" = --version ]; then\n  printf '%s\\n' nightly\n  exit 0\nfi\nexit 72\n")
file(CHMOD "${_plugin_dir}/cargo" "${_plugin_dir}/cargo-fuzz" "${_nightly_bin}/cargo"
  PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
include("${_toolkit}/rust/RustEnvironment.cmake")
_boilerplate_rust_environment(_nested_env_hash _nested_env_fingerprints)
set(_nested_config "${CHECK_BINARY}/nested-toolchain.cmake")
file(WRITE "${_nested_config}"
  "set(FUZZ_CARGO [==[${_nightly_bin}/cargo]==])\n"
  "set(FUZZ_RUSTC [==[${_nightly_bin}/rustc]==])\n"
  "set(FUZZ_CARGO_FUZZ [==[${_plugin_dir}/cargo-fuzz]==])\n"
  "set(FUZZ_BIN [==[${_nightly_bin}]==])\n"
  "set(FUZZ_TARGET_DIR [==[${CHECK_BINARY}/nested-target]==])\n"
  "set(FUZZ_DIR [==[${CHECK_BINARY}]==])\n"
  "set(FUZZ_TARGET scheduler)\n"
  "set(FUZZ_TARGET_TRIPLE x86_64-unknown-linux-gnu)\n"
  "set(FUZZ_SANITIZER address)\n"
  "set(FUZZ_CONFIG Debug)\n"
  "set(FUZZ_ENVIRONMENT_HASH [==[${_nested_env_hash}]==])\n"
  "set(FUZZ_ENVIRONMENT_FINGERPRINTS [==[${_nested_env_fingerprints}]==])\n")
run("${CMAKE_COMMAND}" "-DFUZZ_CONFIG_FILE=${_nested_config}" -DFUZZ_MODE=build
  -P "${_toolkit}/rust/RunFuzz.cmake")
message(STATUS "Rust Stage 3A.2: cargo-fuzz build/run, bounded smoke, replay, corpus persistence, variant separation and fingerprint passed (${CHECK_GENERATOR}; fake drivers)")
