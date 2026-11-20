#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: bash examples/vulkan/reproduce.sh [--plan|--yes]' \
    'Set CMAKEWORKFLOW to the CLI path if it is outside PATH.'
}

case "${1:---plan}" in
  --help) usage; exit 0 ;;
  --plan|--yes) ;;
  *) usage >&2; exit 2 ;;
esac
if (( $# > 1 )); then
  usage >&2
  exit 2
fi

project=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
if ! command -v jq >/dev/null; then
  echo 'jq was not found in PATH.' >&2
  exit 1
fi

cli=${CMAKEWORKFLOW:-}
if [[ -n "$cli" ]]; then
  if ! command -v "$cli" >/dev/null; then
    printf 'CMAKEWORKFLOW points to an unavailable executable: %s\n' "$cli" >&2
    exit 1
  fi
else
  sibling="$project/../../../CMakeWorkflow/bin/Release/net10.0/CMakeWorkflow"
  if command -v CMakeWorkflow >/dev/null; then
    cli=CMakeWorkflow
  elif command -v cmakeworkflow >/dev/null; then
    cli=cmakeworkflow
  elif [[ -f "$sibling" && -x "$sibling" ]]; then
    cli=$sibling
  else
    echo 'CMakeWorkflow was not found. Set CMAKEWORKFLOW to the executable path or add it to PATH.' >&2
    exit 1
  fi
fi

# Keep reports and generated manifests outside the source and Git index.
output=${CMAKEWORKFLOW_VULKAN_OUT:-"$project/../../out/vulkan"}
temp=$(mktemp -d)
publishing=
cleanup() {
  if [[ -n "$publishing" && -f "$publishing" ]]; then
    rm -- "$publishing"
  fi
  rm -rf -- "$temp"
}
trap cleanup EXIT

approve() {
  local name=$1 prefix=$2 digest
  digest=$(sed -n "s/^${prefix}: //p" "$temp/$name.sha")
  if [[ ! "$digest" =~ ^[[:xdigit:]]{64}$ ]]; then
    cat "$temp/$name.sha" >&2
    echo "CMakeWorkflow did not return a valid $prefix." >&2
    return 1
  fi
  printf '%s\n' "$digest"
}

readonly -a tools=(--tool-policy ManagedOnly --profile linux-clang --profile vcpkg)
if ! "$cli" tooling plan "${tools[@]}" --json >"$temp/tools.json" 2>"$temp/tools.sha"; then
  cat "$temp/tools.sha" >&2
  exit 1
fi
if ! "$cli" tooling vcpkg plan "$project" >"$temp/deps.json" 2>"$temp/deps.sha"; then
  cat "$temp/deps.sha" >&2
  exit 1
fi
if [[ "${1:---plan}" == --plan ]]; then
  jq . "$temp/tools.json"
  cat "$temp/tools.sha" >&2
  jq . "$temp/deps.json"
  cat "$temp/deps.sha" >&2
  exit 0
fi

if ! jq -e '.ready == true' "$temp/tools.json" >/dev/null; then
  tool_approval=$(approve tools 'Plan SHA-256')
  "$cli" tooling setup "${tools[@]}" --yes --plan-sha "$tool_approval"
fi
dependency_approval=$(approve deps 'Vcpkg project plan SHA-256')
"$cli" tooling vcpkg install "$project" --yes --plan-sha "$dependency_approval" |
  tee "$temp/installed.log" >&2
deps=$(sed -n 's/^Vcpkg project SHA-256: //p' "$temp/installed.log")
if [[ ! "$deps" =~ ^[[:xdigit:]]{64}$ ]]; then
  echo 'CMakeWorkflow did not return the prepared dependency ID.' >&2
  exit 1
fi
"$cli" tooling lock --write >"$temp/environment.lock.json" 2>"$temp/environment.sha" ||
  { cat "$temp/environment.sha" >&2; exit 1; }
lock=$(approve environment 'Environment lock SHA-256')

mkdir -p "$output"
output=$(cd "$output" && pwd -P)
publishing=$(mktemp "$output/.workflow.XXXXXXXX")
jq --arg source "$project" --arg build "$output/build-$deps" --arg deps "$deps" --arg lock "$lock" '
  .contexts.vulkan.sourceDirectory = $source |
  .contexts.vulkan.buildDirectory = $build |
  .contexts.vulkan.toolchain.vcpkgProjectSha256 = $deps |
  .contexts.vulkan.toolchain.environmentLockSha256 = $lock
' "$project/workflow.json" >"$publishing"
# Use a stable manifest path so workflow resume can reopen it.
manifest="$output/workflow-$deps.json"
mv -- "$publishing" "$manifest"
publishing=
mkdir -p "$output/runs"
results=$(mktemp -d "$output/runs/launch.XXXXXXXX")
if "$cli" workflow run "$manifest" --results-dir "$results" --no-history; then
  exit 0
else
  status=$?
fi

for log in "$results"/*/check-and-dispatch.stdout.log; do
  if [[ -f "$log" ]]; then
    cat "$log" >&2
  fi
done
exit "$status"
