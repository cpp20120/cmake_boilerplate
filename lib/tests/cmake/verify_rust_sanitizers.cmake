cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<temporary directory>")
endif()
if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  message(STATUS "Rust sanitizer regression is Linux-only; skipping")
  return()
endif()
if(NOT CHECK_GENERATOR)
  set(CHECK_GENERATOR Ninja)
endif()
get_filename_component(_toolkit "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
set(_source "${CMAKE_CURRENT_LIST_DIR}/rust/sanitizers")
set(_manifest "${CMAKE_CURRENT_LIST_DIR}/rust/Cargo.toml")
file(REMOVE_RECURSE "${CHECK_BINARY}")
file(MAKE_DIRECTORY "${CHECK_BINARY}")
function(run)
  execute_process(COMMAND ${ARGN} RESULT_VARIABLE _status
    OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
  if(NOT _status STREQUAL "0")
    message(FATAL_ERROR "Rust sanitizers: command failed: ${ARGN}\n${_stdout}\n${_stderr}")
  endif()
endfunction()
function(reject pattern)
  set(_command ${ARGN})
  execute_process(COMMAND ${_command} RESULT_VARIABLE _status
    OUTPUT_VARIABLE _stdout ERROR_VARIABLE _stderr)
  if(_status STREQUAL "0" OR NOT "${_stdout}\n${_stderr}" MATCHES "${pattern}")
    message(FATAL_ERROR "Rust sanitizers: expected '${pattern}' rejection: ${_command}\n${_stdout}\n${_stderr}")
  endif()
endfunction()
# Fake Cargo and rustc are deliberately test-local: these tests validate
# CMake lowering/invocation graphs and diagnostics, not real LLVM sanitizer
# runtime behavior. Real nightly smoke tests must run on an actual toolchain.
function(make_toolchain channel triple with_sources output)
  set(_root "${CHECK_BINARY}/toolchain-${channel}-${triple}-${with_sources}")
  set(_sysroot "${_root}/sysroot")
  file(MAKE_DIRECTORY "${_root}/bin" "${_sysroot}/lib/rustlib/${triple}")
  if(with_sources)
    file(MAKE_DIRECTORY "${_sysroot}/lib/rustlib/src/rust/library")
    file(WRITE "${_sysroot}/lib/rustlib/src/rust/library/Cargo.toml" "[workspace]\n")
  endif()
  set(CHANNEL "-${channel}")
  if(channel STREQUAL "stable")
    set(CHANNEL "")
  endif()
  set(TRIPLE "${triple}")
  set(FAKE_SYSROOT "${_sysroot}")
  set(FAKE_METADATA "${_root}/metadata.json")
  get_filename_component(_workspace "${_manifest}" DIRECTORY)
  set(_metadata "{\"workspace_root\":\"${_workspace}\",\"packages\":[{\"name\":\"rust-fixture\",\"manifest_path\":\"${_manifest}\",\"rust_version\":null,\"targets\":[{\"name\":\"fixture-bin\",\"kind\":[\"bin\"],\"crate_types\":[\"bin\"],\"edition\":\"2021\"}]}]}")
  file(WRITE "${FAKE_METADATA}" "${_metadata}")
  configure_file("${_source}/fake-cargo.sh.in" "${_root}/bin/cargo" @ONLY)
  configure_file("${_source}/fake-rustc.sh.in" "${_root}/bin/rustc" @ONLY)
  file(CHMOD "${_root}/bin/cargo" "${_root}/bin/rustc"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
  set(${output} "${_root}/bin" PARENT_SCOPE)
endfunction()
make_toolchain(nightly x86_64-unknown-linux-gnu TRUE _nightly)
make_toolchain(stable x86_64-unknown-linux-gnu TRUE _stable)
make_toolchain(nightly x86_64-unknown-linux-gnu FALSE _no_src)
make_toolchain(nightly aarch64-unknown-linux-gnu TRUE _wrong_target)
function(configure_case dir bin)
  run("${CMAKE_COMMAND}" -S "${_source}" -B "${CHECK_BINARY}/${dir}" -G "${CHECK_GENERATOR}"
    "-DTOOLKIT_DIR=${_toolkit}" -DCMAKE_BUILD_TYPE=Debug
    "-DBOILERPLATE_RUST_CARGO=${bin}/cargo" "-DBOILERPLATE_RUST_RUSTC=${bin}/rustc"
    ${ARGN})
endfunction()
configure_case(valid "${_nightly}")
set(_build "${CHECK_BINARY}/valid")
file(READ "${_build}/asan-metadata-Debug.txt" _provenance)
if(NOT _provenance MATCHES "rust_sanitizer=address" OR NOT _provenance MATCHES "backend=rust")
  message(FATAL_ERROR "Rust sanitizer benchmark provenance is missing or incorrect")
endif()
foreach(_type IN ITEMS rust_asan rust_tsan rust_plain)
  file(READ "${_build}/rust/${_type}/Debug/cargo.cmake" _config)
  if(_type STREQUAL rust_asan)
    set(_expected address)
  elseif(_type STREQUAL rust_tsan)
    set(_expected thread)
  else()
    set(_expected none)
  endif()
  if(NOT _config MATCHES "RUST_SANITIZER.*${_expected}")
    message(FATAL_ERROR "Rust ${_type}: wrong sanitizer configuration")
  endif()
  if(NOT _expected STREQUAL none)
    if(NOT _config MATCHES "-Zsanitizer=${_expected}" OR NOT _config MATCHES "-Zbuild-std")
      message(FATAL_ERROR "Rust ${_type}: sanitizer flags or standard library instrumentation missing")
    endif()
  else()
    if(_config MATCHES "-Zsanitizer=" OR _config MATCHES "-Zbuild-std")
      message(FATAL_ERROR "Rust plain: unexpected instrumentation")
    endif()
  endif()
  file(STRINGS "${_build}/rust/${_type}/Debug/cargo.cmake" _dir_line REGEX "^set\\(RUST_TARGET_DIR ")
  list(APPEND _dirs "${_dir_line}")
endforeach()
list(REMOVE_DUPLICATES _dirs)
list(LENGTH _dirs _num_dirs)
if(NOT _num_dirs EQUAL 3)
  message(FATAL_ERROR "Sanitized and unsanitized variants share Cargo artifact identity")
endif()
# Regression: an external build launcher may inject CXX after configure.
# Cargo must run under the originally recorded native environment, rather than
# accepting this new compiler value or rejecting a reproducible variant.
if(NOT DEFINED ENV{CXX})
  run("${CMAKE_COMMAND}" -E env "CXX=/invalid/compiler/from/build-launcher"
    "${CMAKE_COMMAND}" --build "${_build}" --target
    rust_asan_cargo rust_tsan_cargo rust_plain_cargo
    rust_asan_suite_cargo_tests rust_tsan_suite_cargo_tests)
else()
  run("${CMAKE_COMMAND}" --build "${_build}" --target
    rust_asan_cargo rust_tsan_cargo rust_plain_cargo
    rust_asan_suite_cargo_tests rust_tsan_suite_cargo_tests)
endif()
run("${CMAKE_CTEST_COMMAND}" --test-dir "${_build}" -C Debug -R "^rust_(asan|tsan)_suite$" --output-on-failure)
# A compiler override present at configure time remains a build input:
# changing it later must still fail the fingerprint check.
if(NOT DEFINED ENV{CXX})
  run("${CMAKE_COMMAND}" -E env "CXX=/configured/native/compiler"
    "${CMAKE_COMMAND}" -S "${_source}" -B "${CHECK_BINARY}/native-snapshot"
      -G "${CHECK_GENERATOR}" "-DTOOLKIT_DIR=${_toolkit}" -DCMAKE_BUILD_TYPE=Debug
      "-DBOILERPLATE_RUST_CARGO=${_nightly}/cargo"
      "-DBOILERPLATE_RUST_RUSTC=${_nightly}/rustc"
      -DFIXTURE_SKIP_SANITIZERS=ON)
  reject("changed keys: CXX" "${CMAKE_COMMAND}" -E env
    "CXX=/different/native/compiler" "${CMAKE_COMMAND}" --build
    "${CHECK_BINARY}/native-snapshot" --target rust_plain_cargo)
endif()
# Rust-specific compilation inputs must never be silently normalized away.
reject("RUSTFLAGS" "${CMAKE_COMMAND}" -E env
  "RUSTFLAGS=-Copt-level=1" "${CMAKE_COMMAND}" --build "${_build}" --target rust_plain_cargo)
foreach(_type IN ITEMS rust_asan rust_tsan rust_plain)
  file(STRINGS "${_build}/rust/${_type}/Debug/cargo.cmake" _dir_line REGEX "^set\\(RUST_TARGET_DIR ")
  if(NOT _dir_line MATCHES "^set\\(RUST_TARGET_DIR \\[==\\[(.*)\\]==\\]\\)$")
    message(FATAL_ERROR "Cannot parse Cargo target directory: ${_dir_line}")
  endif()
  set(_dir "${CMAKE_MATCH_1}")
  file(READ "${_dir}/last-invocation.txt" _invocation)
  if(_type STREQUAL rust_plain)
    if(_invocation MATCHES "build_std=yes" OR _invocation MATCHES "-Zsanitizer=")
      message(FATAL_ERROR "Rust plain: runtime invocation unexpectedly instrumented")
    endif()
  else()
    if(NOT _invocation MATCHES "build_std=yes")
      message(FATAL_ERROR "Rust ${_type}: Cargo invocation did not rebuild std")
    endif()
    if(_type STREQUAL rust_asan AND NOT _invocation MATCHES "-Zsanitizer=address")
      message(FATAL_ERROR "Rust ASan: missing compiler instrumentation")
    elseif(_type STREQUAL rust_tsan AND NOT _invocation MATCHES "-Zsanitizer=thread")
      message(FATAL_ERROR "Rust TSan: missing compiler instrumentation")
    endif()
  endif()
endforeach()
# Configuration errors must be explicit; none must still work on stable.
configure_case(stable-plain "${_stable}" -DFIXTURE_SKIP_SANITIZERS=ON)
reject("requires matching nightly" "${CMAKE_COMMAND}" -S "${_source}"
  -B "${CHECK_BINARY}/stable-bad" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${_stable}/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${_stable}/rustc")
reject("requires rust-src" "${CMAKE_COMMAND}" -S "${_source}"
  -B "${CHECK_BINARY}/missing-src" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${_no_src}/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${_no_src}/rustc")
reject("supports only Linux" "${CMAKE_COMMAND}" -S "${_source}"
  -B "${CHECK_BINARY}/unsupported-target" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${_wrong_target}/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${_wrong_target}/rustc")
reject("is unsupported" "${CMAKE_COMMAND}" -S "${_source}"
  -B "${CHECK_BINARY}/unsupported-san" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${_nightly}/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${_nightly}/rustc" -DFIXTURE_UNSUPPORTED_SANITIZER=ON)
reject("specify SANITIZER as a policy" "${CMAKE_COMMAND}" -S "${_source}"
  -B "${CHECK_BINARY}/raw-san" -G Ninja "-DTOOLKIT_DIR=${_toolkit}"
  -DCMAKE_BUILD_TYPE=Debug "-DBOILERPLATE_RUST_CARGO=${_nightly}/cargo"
  "-DBOILERPLATE_RUST_RUSTC=${_nightly}/rustc" -DFIXTURE_SKIP_SANITIZERS=ON -DFIXTURE_RAW_SANITIZER=ON)
message(STATUS "Rust Stage 3A.1: sanitizer policy, variants, nightly/rust-src gating, Cargo/CTest commands passed (${CHECK_GENERATOR}; fake toolchain)")
