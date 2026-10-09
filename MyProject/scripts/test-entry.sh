#!/usr/bin/env bash
# Offline regression for the user-facing shell entry. No installs or Python.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
bash "$root/setup.sh" --dry-run --manager apt --init DemoProject \
  --output "$work/demo path" --profile minimal --run --package > "$work/init.log"
grep -q 'Would create DemoProject' "$work/init.log"
grep -q 'Would configure, build' "$work/init.log"
test ! -e "$work/demo path"
bash "$root/build.sh" --dry-run --preset app-debug --run --no-tests --jobs 3 > "$work/build.log"
grep -q -- '-DRUN_APPLICATION=ON' "$work/build.log"
grep -q -- '-DRUN_TESTS=OFF' "$work/build.log"
grep -q -- '-DJOBS=3' "$work/build.log"
bash "$root/build.sh" --dry-run --package --package-format TGZ > "$work/package.log"
grep -q -- '-DPACKAGE_ARTIFACTS=ON' "$work/package.log"
grep -q -- '-DPACKAGE_FORMAT=TGZ' "$work/package.log"
bash "$root/build.sh" --dry-run --package-format ARCH > "$work/arch.log"
grep -q -- '-DPACKAGE_FORMAT=ARCH' "$work/arch.log"
bash "$root/setup.sh" --dry-run --manager apt --package --no-tests > "$work/setup-package.log"
grep -q 'profile: package' "$work/setup-package.log"
bash "$root/setup.sh" --dry-run --manager apt --setup-only > "$work/setup-only.log"
if grep -q 'BuildMatrix.cmake' "$work/setup-only.log"; then
  echo 'setup-only unexpectedly executed a build'; exit 1
fi
for invalid in '--init' '--output x' '--jobs -5' '--preset ../../wrong' '--init Bad__Name' '--run-target bad/target' '--package-format NOT_REAL'; do
  # Deliberate word splitting of fixed invalid arguments.
  if bash "$root/setup.sh" --dry-run $invalid >/dev/null 2>&1; then
    echo "Accepted invalid arguments: $invalid"; exit 1
  fi
done
echo 'One-command shell bootstrap checks passed.'
