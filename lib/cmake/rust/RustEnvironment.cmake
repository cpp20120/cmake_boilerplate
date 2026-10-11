include_guard(GLOBAL)

# Track build-affecting environment, never registry credentials. Used during
# configure and invocation: a changed ambient build context requires reconfigure.
function(_boilerplate_rust_environment output)
  execute_process(COMMAND "${CMAKE_COMMAND}" -E environment OUTPUT_VARIABLE _env)
  string(REPLACE "\n" ";" _lines "${_env}")
  set(_entries)
  foreach(_line IN LISTS _lines)
    if(_line MATCHES "^(RUSTFLAGS|CARGO_ENCODED_RUSTFLAGS|RUSTC_WRAPPER|RUSTC_WORKSPACE_WRAPPER|RUSTUP_TOOLCHAIN|CARGO_HOME|CARGO_INCREMENTAL|CARGO_BUILD_[A-Z0-9_]+|CARGO_PROFILE_[A-Z0-9_]+|CARGO_TARGET_[A-Z0-9_]+|CC|CXX|AR|CFLAGS|CXXFLAGS|LDFLAGS)=")
      list(APPEND _entries "${_line}")
    endif()
  endforeach()
  list(SORT _entries)
  string(SHA256 _hash "${_entries}")
  set(${output} "${_hash}" PARENT_SCOPE)
endfunction()
