include_guard(GLOBAL)

# Track build-affecting environment, never registry credentials. Used during
# configure and invocation: a changed ambient build context requires reconfigure.
function(_boilerplate_rust_environment output)
  execute_process(COMMAND "${CMAKE_COMMAND}" -E environment OUTPUT_VARIABLE _env)
  string(REPLACE "\n" ";" _lines "${_env}")
  set(_entries)
  foreach(_line IN LISTS _lines)
    if(_line MATCHES "^(RUSTFLAGS|CARGO_ENCODED_RUSTFLAGS|RUSTC_WRAPPER|RUSTC_WORKSPACE_WRAPPER|RUSTUP_TOOLCHAIN|CARGO_HOME|CARGO_INCREMENTAL|CARGO_BUILD_[A-Z0-9_]+|CARGO_PROFILE_[A-Z0-9_]+|CARGO_TARGET_[A-Z0-9_]+|CC|CXX|AR|CFLAGS|CXXFLAGS|LDFLAGS)=")
      # CARGO_TARGET_TMPDIR is set by Cargo for runtime test execution, not
      # a compiler configuration input. Do not fingerprint that transient path.
      if(_line MATCHES "^CARGO_TARGET_TMPDIR=")
        continue()
      endif()
      list(APPEND _entries "${_line}")
    endif()
  endforeach()
  list(SORT _entries)
  string(SHA256 _hash "${_entries}")
  set(${output} "${_hash}" PARENT_SCOPE)
  # Optional redacted snapshot: only names and hashes, never actual values.
  # It explains which ambient build input changed, rather than forcing the
  # developer to guess why CTest and a direct CMake invocation differ.
  if(ARGC GREATER 1)
    set(_fingerprints)
    foreach(_entry IN LISTS _entries)
      string(FIND "${_entry}" "=" _pos)
      string(SUBSTRING "${_entry}" 0 ${_pos} _name)
      string(SHA256 _digest "${_entry}")
      list(APPEND _fingerprints "${_name}=${_digest}")
    endforeach()
    set(${ARGV1} "${_fingerprints}" PARENT_SCOPE)
  endif()
endfunction()
