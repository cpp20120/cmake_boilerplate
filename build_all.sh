#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# All policy lives in presets and BuildMatrix.cmake. Forward -D knobs verbatim.
exec cmake "-DSOURCE_DIR=${root}" "$@" -P "${root}/lib/cmake/build/BuildMatrix.cmake"
