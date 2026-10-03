cmake_minimum_required(VERSION 3.26)
if(NOT CHECK_BINARY)
  message(FATAL_ERROR "Pass -DCHECK_BINARY=<temporary build directory>")
endif()
find_program(_ninja ninja REQUIRED)
get_filename_component(_modules "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)
set(_fixture "${CHECK_BINARY}/vcpkg-discovery")
file(REMOVE_RECURSE "${_fixture}")
file(MAKE_DIRECTORY "${_fixture}")

function(fake_vcpkg root)
  file(MAKE_DIRECTORY "${root}/scripts/buildsystems")
  file(WRITE "${root}/scripts/buildsystems/vcpkg.cmake" "# Offline discovery fixture\n")
endfunction()

function(check name expected)
  cmake_parse_arguments(PARSE_ARGV 2 ARG "" "ERROR" "ARGS;ENV")
  set(_source "${_fixture}/${name}")
  file(MAKE_DIRECTORY "${_source}")
  file(WRITE "${_source}/CMakeLists.txt" "
cmake_minimum_required(VERSION 3.26)
include(\"${_modules}/Bootstrap.cmake\")
boilerplate_bootstrap()
project(DiscoveryFixture LANGUAGES NONE)
file(WRITE \"\${CMAKE_BINARY_DIR}/selected.txt\" \"\${CMAKE_TOOLCHAIN_FILE}\")
")
  execute_process(COMMAND "${CMAKE_COMMAND}" -E env
    --unset=VCPKG_ROOT --unset=CMAKE_TOOLCHAIN_FILE --unset=VSINSTALLDIR
    --unset=HOME --unset=USERPROFILE --unset=LOCALAPPDATA "PATH=" ${ARG_ENV}
    "${CMAKE_COMMAND}" -S "${_source}" -B "${_source}/build" -G Ninja
    "-DCMAKE_MAKE_PROGRAM=${_ninja}" -DBOILERPLATE_DEPENDENCY_PROVIDER=vcpkg ${ARG_ARGS}
    RESULT_VARIABLE _result OUTPUT_VARIABLE _output ERROR_VARIABLE _error)
  if(ARG_ERROR)
    if(_result EQUAL 0 OR NOT "${_output}${_error}" MATCHES "${ARG_ERROR}")
      message(FATAL_ERROR "${name}: expected failure matching ${ARG_ERROR}: ${_output}${_error}")
    endif()
  else()
    if(NOT _result EQUAL 0)
      message(FATAL_ERROR "${name}: ${_output}${_error}")
    endif()
    file(READ "${_source}/build/selected.txt" _selected)
    if(NOT _selected STREQUAL expected)
      message(FATAL_ERROR "${name}: expected ${expected}, got ${_selected}")
    endif()
  endif()
endfunction()

fake_vcpkg("${_fixture}/explicit root")
fake_vcpkg("${_fixture}/environment")
set(_explicit "${_fixture}/explicit root/scripts/buildsystems/vcpkg.cmake")
check(explicit "${_explicit}"
  ARGS "-DBOILERPLATE_VCPKG_ROOT=${_fixture}/explicit root"
  ENV "VCPKG_ROOT=${_fixture}/environment")
check(variable "${_explicit}" ARGS "-DVCPKG_ROOT=${_fixture}/explicit root"
  ENV "VCPKG_ROOT=${_fixture}/environment")
check(relative "${_explicit}" ARGS "-DVCPKG_ROOT=../explicit root")
check(environment "${_fixture}/environment/scripts/buildsystems/vcpkg.cmake"
  ENV "VCPKG_ROOT=${_fixture}/environment")
check(toolchain "${_explicit}" ARGS "-DCMAKE_TOOLCHAIN_FILE=${_explicit}"
  ENV "VCPKG_ROOT=${_fixture}/missing")
check(toolchain-env "${_explicit}" ENV "CMAKE_TOOLCHAIN_FILE=${_explicit}"
  "VCPKG_ROOT=${_fixture}/missing")

foreach(_location IN ITEMS vcpkg external/vcpkg third_party/vcpkg)
  string(REPLACE "/" "-" _name "local-${_location}")
  set(_local "${_fixture}/${_name}/${_location}")
  fake_vcpkg("${_local}")
  check("${_name}" "${_local}/scripts/buildsystems/vcpkg.cmake")
endforeach()
fake_vcpkg("${_fixture}/home/vcpkg")
foreach(_env IN ITEMS HOME USERPROFILE LOCALAPPDATA)
  check("home-${_env}" "${_fixture}/home/vcpkg/scripts/buildsystems/vcpkg.cmake"
    ENV "${_env}=${_fixture}/home")
endforeach()
fake_vcpkg("${_fixture}/visual studio/VC/vcpkg")
check(visual-studio "${_fixture}/visual studio/VC/vcpkg/scripts/buildsystems/vcpkg.cmake"
  ENV "VSINSTALLDIR=${_fixture}/visual studio/")

set(_path_root "${_fixture}/path root")
fake_vcpkg("${_path_root}")
if(WIN32)
  set(_binary vcpkg.exe)
else()
  set(_binary vcpkg)
endif()
file(WRITE "${_path_root}/${_binary}" "# Never executed\n")
file(CHMOD "${_path_root}/${_binary}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE)
check(path "${_path_root}/scripts/buildsystems/vcpkg.cmake" ENV "PATH=${_path_root}"
  "HOME=${_fixture}/home")
fake_vcpkg("${_fixture}/local-priority/vcpkg")
check(local-priority "${_fixture}/local-priority/vcpkg/scripts/buildsystems/vcpkg.cmake"
  ENV "PATH=${_path_root}")
if(UNIX)
  file(MAKE_DIRECTORY "${_fixture}/bin")
  file(CREATE_LINK "${_path_root}/${_binary}" "${_fixture}/bin/vcpkg" SYMBOLIC)
  check(symlink "${_path_root}/scripts/buildsystems/vcpkg.cmake" ENV "PATH=${_fixture}/bin")
endif()
check(invalid "" ARGS "-DBOILERPLATE_VCPKG_ROOT=${_fixture}/missing"
  ENV "HOME=${_fixture}/home" ERROR "Explicit vcpkg root")
check(missing "" ERROR "vcpkg was not found")
check(system "" ARGS -DBOILERPLATE_DEPENDENCY_PROVIDER=system
  ENV "VCPKG_ROOT=${_fixture}/missing")

# The matrix must use the same local discovery before its registry preflight.
fake_vcpkg("${_fixture}/matrix/vcpkg")
check(matrix "${_fixture}/matrix/vcpkg/scripts/buildsystems/vcpkg.cmake")
file(WRITE "${_fixture}/matrix/CMakePresets.json" "{
  \"version\": 6,
  \"configurePresets\": [{\"name\": \"vcpkg-auto\", \"generator\": \"Ninja\",
    \"binaryDir\": \"\${sourceDir}/matrix-build\",
    \"cacheVariables\": {\"BOILERPLATE_DEPENDENCY_PROVIDER\": \"vcpkg\",
      \"CMAKE_MAKE_PROGRAM\": \"${_ninja}\"}}],
  \"buildPresets\": [{\"name\": \"vcpkg-auto\", \"configurePreset\": \"vcpkg-auto\"}]
}")
execute_process(COMMAND "${CMAKE_COMMAND}" -E env --unset=VCPKG_ROOT
  --unset=CMAKE_TOOLCHAIN_FILE --unset=VSINSTALLDIR --unset=HOME
  --unset=USERPROFILE --unset=LOCALAPPDATA "PATH="
  "${CMAKE_COMMAND}" "-DSOURCE_DIR=${_fixture}/matrix" -DPRESETS=vcpkg-auto
  -DRUN_TESTS=OFF -DINSTALL_ARTIFACTS=OFF -P "${_modules}/BuildMatrix.cmake"
  RESULT_VARIABLE _result OUTPUT_VARIABLE _output ERROR_VARIABLE _error)
if(NOT _result EQUAL 0)
  message(FATAL_ERROR "Matrix discovery failed: ${_output}${_error}")
endif()
file(READ "${_fixture}/matrix/matrix-build/selected.txt" _selected)
if(NOT _selected STREQUAL "${_fixture}/matrix/vcpkg/scripts/buildsystems/vcpkg.cmake")
  message(FATAL_ERROR "Matrix selected the wrong toolchain: ${_selected}")
endif()
message(STATUS "vcpkg discovery, explicit overrides and missing-root diagnostics passed")
