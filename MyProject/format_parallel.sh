#!/bin/bash

EXCLUDED_DIRS="build\|vcpkg_installed"

FILES=$(find . -type f \( -name "*.cpp" -o -name "*.h" \) | grep -v "$EXCLUDED_DIRS")

CORES=$(nproc)

echo "$FILES" | xargs -P "$CORES" -I {} sh -c '
    echo "Formatting: {}"
    clang-format -i "{}"
'

echo "Formatting complete!"