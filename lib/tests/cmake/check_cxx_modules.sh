#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "${1:-.}" && pwd)"
if [[ ! -f "$repo/lib/cmake/Boilerplate.cmake" ]]; then
  printf 'Expected cmake_boilerplate checkout as first argument: %s\n' "$repo" >&2
  exit 2
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/cmake-boilerplate-modules.XXXXXXXX")"
printf 'C++ modules smoke workspace: %s\n' "$work"
mkdir -p "$work/project/src" "$work/project/include" "$work/consumer"

cat > "$work/project/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.28)
project(BoilerplateModulesSmoke VERSION 1.0.0 LANGUAGES CXX)
include(CTest)
include("${TOOLKIT_DIR}/Boilerplate.cmake")
boilerplate_project(CAPABILITIES project-minimal)

boilerplate_add_library(math
  SOURCES src/math.cpp
  PUBLIC_MODULES src/math.cppm
  PRIVATE_MODULES src/math_internal.cppm
  INCLUDE_DIR include
  POLICIES minimal)

boilerplate_add_executable(modules_shared
  SOURCES src/main.cpp LIBRARIES math::shared POLICIES minimal)
boilerplate_add_executable(modules_static
  SOURCES src/main.cpp LIBRARIES math::static POLICIES minimal)
add_test(NAME modules_shared COMMAND modules_shared)
add_test(NAME modules_static COMMAND modules_static)
boilerplate_finalize_project()
CMAKE

cat > "$work/project/src/math.cppm" <<'CPP'
module;
#include "math_export.h"
export module math;
export MATH_EXPORT int twice(int value);
CPP
cat > "$work/project/src/math_internal.cppm" <<'CPP'
export module math.internal;
export int double_value(int value) { return value * 2; }
CPP
cat > "$work/project/src/math.cpp" <<'CPP'
module math;
import math.internal;
int twice(int value) { return double_value(value); }
CPP
cat > "$work/project/src/main.cpp" <<'CPP'
import math;
int main() { return twice(21) == 42 ? 0 : 1; }
CPP

compiler="${CXX:-clang++}"
printf '\n[1/5] Configure + compile with %s\n' "$compiler"
cmake -S "$work/project" -B "$work/build" -G Ninja \
  "-DTOOLKIT_DIR=$repo/lib/cmake" \
  "-DCMAKE_CXX_COMPILER=$compiler" \
  -DBOILERPLATE_CXX_STANDARD=23 \
  -DBOILERPLATE_BUILD_SHARED=ON -DBOILERPLATE_BUILD_STATIC=ON \
  -DBOILERPLATE_COMPILER_CACHE=none
cmake --build "$work/build" --parallel 4

printf '\n[2/5] Both variants pass CTest\n'
ctest --test-dir "$work/build" --output-on-failure

printf '\n[3/5] Incremental rebuild after editing module interface\n'
printf '\n// module incremental change\n' >> "$work/project/src/math.cppm"
cmake --build "$work/build" --parallel 4
ctest --test-dir "$work/build" --output-on-failure

printf '\n[4/5] Install and relocate export prefix\n'
cmake --install "$work/build" --prefix "$work/installed"
mv "$work/installed" "$work/relocated"

cat > "$work/consumer/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.28)
project(BoilerplateModulesConsumer LANGUAGES CXX)
find_package(math CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_compile_features(consumer PRIVATE cxx_std_23)
set_target_properties(consumer PROPERTIES CXX_SCAN_FOR_MODULES ON)
target_link_libraries(consumer PRIVATE math::shared)
CMAKE
cat > "$work/consumer/main.cpp" <<'CPP'
import math;
int main() { return twice(21) == 42 ? 0 : 1; }
CPP

printf '\n[5/5] Configure, build and run an external consumer\n'
cmake -S "$work/consumer" -B "$work/consumer-build" -G Ninja \
  "-DCMAKE_CXX_COMPILER=$compiler" \
  "-DCMAKE_PREFIX_PATH=$work/relocated"
cmake --build "$work/consumer-build" --parallel 4
"$work/consumer-build/consumer"

printf '\nPASS: build, CTest, incremental rebuild, install/relocation, external consumer.\n'
printf 'Workspace retained at: %s\n' "$work"
