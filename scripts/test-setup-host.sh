#!/usr/bin/env bash
# Offline checks with a deliberately minimal PATH and no Python executable.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
for tool in bash dirname basename uname; do ln -s "$(command -v "$tool")" "$work/bin/$tool"; done
# Any attempt to execute a package manager in dry-run is a test failure.
for tool in apt-get dnf pacman brew sudo git; do
  cat > "$work/bin/$tool" <<'MOCK'
#!/bin/bash
printf 'unexpected installer execution\n' >> "$SETUP_TEST_MARKER"
exit 90
MOCK
  chmod +x "$work/bin/$tool"
done
# brew --prefix is a read-only query made by the script.
cat > "$work/bin/brew" <<'MOCK'
#!/bin/bash
if [[ "$1" == --prefix ]]; then echo /not-installed-brew; exit 0; fi
printf 'unexpected brew install\n' >> "$SETUP_TEST_MARKER"
exit 90
MOCK
export SETUP_TEST_MARKER="$work/mutated"
for manager in apt dnf pacman brew; do
  PATH="$work/bin" /bin/bash "$root/setup-host.sh" --dry-run --manager "$manager" \
    --tools-dir "$work/tools with spaces" --vcpkg-root "$work/new vcpkg" > "$work/$manager.log"
  test ! -e "$work/mutated"
  test ! -e "$work/tools with spaces"
  test ! -e "$work/new vcpkg"
  for expected in cmake ninja sccache ccache vcpkg.git; do grep -qi "$expected" "$work/$manager.log"; done
  if grep -Ei 'pip|venv|python' "$work/$manager.log"; then echo 'Unexpected Python install command'; exit 1; fi
done
for arguments in '--check --install' '--with-emscripten' '--tools-dir'; do
  # Intentional splitting: these are fixed invalid argument lists.
  if PATH="$work/bin" /bin/bash "$root/setup-host.sh" $arguments > /dev/null 2>&1; then exit 1; fi
done
if PATH="$work/bin" /bin/bash "$root/setup-host.sh" --dry-run --vcpkg-root "$root/vcpkg/../vcpkg" > /dev/null 2>&1; then exit 1; fi
if PATH="$work/bin" /bin/bash "$root/setup-host.sh" --check-harness > "$work/harness.log" 2>&1; then exit 1; fi
grep -q 'Install it separately' "$work/harness.log"
# --check must not run a package manager or invoke Python either.
if PATH="$work/bin" /bin/bash "$root/setup-host.sh" --check --manager apt --vcpkg-root "$work/new vcpkg" > "$work/check.log"; then exit 1; fi
grep -q 'MISSING.*clangd' "$work/check.log"
test ! -e "$work/mutated"
# Exercise environment writing and propagation of failed installation/checks.
# Existing vcpkg is reused and never pulled/reset.
mkdir -p "$work/sdk ' literal/scripts/buildsystems"
touch "$work/sdk ' literal/scripts/buildsystems/vcpkg.cmake"
printf '#!/bin/bash\nexit 0\n' > "$work/sdk ' literal/vcpkg"
chmod +x "$work/sdk ' literal/vcpkg"
for tool in apt-get sudo; do
  printf '#!/bin/bash\nexit 0\n' > "$work/bin/$tool"
done
ln -s "$(command -v mkdir)" "$work/bin/mkdir"
if PATH="$work/bin" /bin/bash "$root/setup-host.sh" --install --manager apt \
  --vcpkg-root "$work/sdk ' literal" --tools-dir "$work/env ' literal" > "$work/install.log" 2>&1; then
  echo 'Incomplete installation must fail'; exit 1
fi
# Only run the mock install on Linux/apt hosts; other platforms reject the manager.
if [[ -f "$work/env ' literal/env.sh" ]]; then
  observed="$(/bin/bash -c 'source "$1"; printf "%s" "$VCPKG_ROOT"' check "$work/env ' literal/env.sh")"
  test "$observed" = "$work/sdk ' literal"
  grep -q 'Setup incomplete' "$work/install.log"
fi
# Reject a transitive Python install before the real package-manager transaction.
cat > "$work/bin/apt-get" <<'MOCK'
#!/bin/bash
if [[ "$1" == -s ]]; then echo 'Inst python3 (3.12 example)'; exit 0; fi
if [[ "$1" == install ]]; then echo 'forbidden transaction' >> "$SETUP_TEST_MARKER"; exit 91; fi
exit 0
MOCK
if PATH="$work/bin" /bin/bash "$root/setup-host.sh" --install --manager apt \
  --vcpkg-root "$work/sdk ' literal" --tools-dir "$work/guard-env" > "$work/guard.log" 2>&1; then exit 1; fi
if [[ -f "$work/guard-env/env.sh" ]]; then grep -q 'has a Python dependency' "$work/guard.log"; fi
test ! -e "$work/mutated"
echo 'Native shell setup checks passed (Python absent from PATH).'
