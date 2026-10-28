#!/usr/bin/env bash
# Offline container wrapper regression: no Docker daemon or network required.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cat > "$work/engine" <<'DRIVER'
#!/bin/sh
printf '%s\n' "$@" > "$BOILERPLATE_CONTAINER_TEST_ARGS"
DRIVER
chmod +x "$work/engine"
export BOILERPLATE_CONTAINER_TEST_ARGS="$work/args"

bash "$root/tools/container.sh" dev --docker "$work/engine"
grep -Fxq -- 'devcontainer' "$work/args"
grep -Fxq -- "$root/.devcontainer/Dockerfile" "$work/args"

bash "$root/tools/container.sh" shell --no-build --docker "$work/engine"
grep -Fxq -- 'zsh' "$work/args"
grep -Fxq -- "$root:/workspace" "$work/args"

bash "$root/tools/container.sh" test --preset app-release --docker "$work/engine"
grep -Fxq -- 'test' "$work/args"
grep -Fxq -- "$root/Dockerfile" "$work/args"
grep -Fxq -- 'CMAKE_PRESET=app-release' "$work/args"

bash "$root/tools/container.sh" run --no-build --docker "$work/engine" -- '--arg with spaces'
grep -Fxq -- '--arg with spaces' "$work/args"

if bash "$root/tools/container.sh" shell --no-build --docker "$work/engine" -- extra > /dev/null 2>&1; then
  echo 'Accepted application arguments for shell action' >&2
  exit 1
fi
echo 'Offline container wrapper checks passed.'
