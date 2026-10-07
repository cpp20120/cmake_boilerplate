#!/bin/bash
# Ultra-fast CMake formatter (bash)

set -eo pipefail

# ===== CONFIGURATION =====
EXCLUDE_DIRS=(
    "build"
    "cmake-build-*"
    "out"
    "bin"
    "install"
    "vcpkg_installed"
    "*/Debug"
    "*/Release"
)

# ===== BUILD EXCLUDE ARGS =====
# Генерируем аргументы для find
find_exclude_args=()
for dir in "${EXCLUDE_DIRS[@]}"; do
    find_exclude_args+=(-not -path "*/$dir/*")
done

if command -v fd &>/dev/null; then
    echo "Using fd for ultra-fast search..."
    exclude_args=()
    for dir in "${EXCLUDE_DIRS[@]}"; do
        exclude_args+=(--exclude "$dir")
    done
    
    mapfile -t files < <(fd --type f -e cmake -e txt "${exclude_args[@]}" | grep -E 'CMakeLists\.txt$|\.cmake$')
else
    # Fallback на find
    echo "Using find (slower, consider installing fd)"
    mapfile -t files < <(find . -type f \( -name 'CMakeLists.txt' -o -name '*.cmake' \) \
        "${find_exclude_args[@]}" -print)
fi

# This source directory deliberately shares the name of an excluded build tree.
module_build_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/cmake/build"
if [[ -d "$module_build_dir" ]]; then
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find "$module_build_dir" -type f -name '*.cmake' -print0)
fi

if [ ${#files[@]} -eq 0 ]; then
    echo "No CMake files found matching criteria" >&2
    exit 0
fi

echo "📝 Formatting ${#files[@]} CMake files..."

cmake-format --version >/dev/null

start_time=$(date +%s.%N)

counter=0
for file in "${files[@]}"; do
    {
        cmake-format --check=false -i "$file" 2>/dev/null
        ((counter++))
        printf "\r🚀 Progress: %d/%d (%.1f%%)" \
            "$counter" "${#files[@]}" \
            $(echo "100*$counter/${#files[@]}" | bc -l)
    } &
    if (( $(jobs -r -p | wc -l) >= $(nproc) )); then
        wait -n
    fi
done
wait

end_time=$(date +%s.%N)
elapsed=$(echo "$end_time - $start_time" | bc -l | xargs printf "%.1f")

echo -e "\n✅ Successfully formatted ${#files[@]} files in ${elapsed}s"
