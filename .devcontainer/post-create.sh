#!/usr/bin/env bash
set -euo pipefail

cd /workspace
sudo chown -R "$(id -u):$(id -g)" /workspace/out
# Refresh the container-only cache when upgrading an existing GCC-based image.
cmake --fresh --preset app-debug -DBOILERPLATE_USE_LLD=ON
# CMake Tools refreshes this copy after subsequent editor configurations.
cp out/build/app-debug/compile_commands.json out/compile_commands.json
