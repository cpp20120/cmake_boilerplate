#!/usr/bin/env bash
# Bash 3.2+ (including macOS system Bash); no Python/pip/venv bootstrap.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
mode= manager= tools_dir="$root/out/host-tools" vcpkg_root="${VCPKG_ROOT:-$HOME/vcpkg}"
fail() { echo "Host setup: $*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: setup-host.sh --install|--check|--dry-run|--check-harness [options]
  --manager apt|dnf|pacman|brew  Override detection for dry-run
  --tools-dir PATH             Activation file directory (out/host-tools)
  --vcpkg-root PATH            Existing/new SDK checkout ($VCPKG_ROOT or ~/vcpkg)
Python is not used by setup. --check-harness separately checks an existing Python.
HELP
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install|--check|--dry-run|--check-harness)
      [[ -z "$mode" ]] || fail 'Choose exactly one mode.'
      mode="$1"; shift ;;
    --manager|--tools-dir|--vcpkg-root)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail "Missing value for $1"
      case "$1" in --manager) manager="$2";; --tools-dir) tools_dir="$2";; --vcpkg-root) vcpkg_root="$2";; esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done
[[ -n "$mode" ]] || { usage; exit 1; }
if [[ "$mode" == --check-harness ]]; then
  if command -v python3 >/dev/null 2>&1; then python3 --version
  else fail 'Optional harness needs Python 3. Install it separately; normal setup/build does not require it.'; fi
  exit 0
fi
canonical_path() {
  local path="$1" parent leaf
  if [[ -d "$path" ]]; then (cd "$path" && pwd -P); return; fi
  parent="$(dirname "$path")"; leaf="$(basename "$path")"
  parent="$(canonical_path "$parent")"
  case "$leaf" in .) printf '%s\n' "$parent";; ..) dirname "$parent";; *) printf '%s/%s\n' "${parent%/}" "$leaf";; esac
}
tools_dir="$(canonical_path "$tools_dir")"
vcpkg_root="$(canonical_path "$vcpkg_root")"
[[ "$vcpkg_root" != "$(canonical_path "$root/vcpkg")" ]] || fail 'vcpkg/ holds overlays; choose ~/vcpkg or external/vcpkg.'
if [[ -e "$vcpkg_root" && ! -f "$vcpkg_root/scripts/buildsystems/vcpkg.cmake" ]]; then
  fail "$vcpkg_root exists but is not a vcpkg checkout."
fi
detect_manager() {
  if [[ "$(uname -s)" == Darwin ]]; then echo brew
  elif command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  else return 1; fi
}
if [[ -z "$manager" ]]; then manager="$(detect_manager)" || fail 'Supported: apt, dnf, pacman, Homebrew.'; fi
case "$manager" in apt|dnf|pacman|brew) ;; *) fail "Unsupported manager: $manager";; esac
if [[ "$mode" == --install ]]; then
  [[ "$manager" == "$(detect_manager)" ]] || fail 'Manager does not match the host.'
fi
extra_path="$vcpkg_root"
refresh_path() {
  if [[ "$manager" == brew ]] && command -v brew >/dev/null 2>&1; then
    local prefix
    prefix="$(brew --prefix)"
    extra_path="$vcpkg_root:$prefix/opt/llvm/bin:$prefix/opt/lld/bin:$prefix/opt/coreutils/libexec/gnubin"
  fi
  export PATH="$extra_path:$PATH"
}
refresh_path
run() {
  printf '+'; printf ' %q' "$@"; printf '\n'
  if [[ "$mode" != --dry-run ]]; then "$@"; fi
}
elevated() {
  if [[ $EUID -eq 0 ]]; then run "$@"; else run sudo "$@"; fi
}
select_package() {
  case "$manager" in apt) package="$apt";; dnf) package="$dnf";; pacman) package="$pacman";; brew) package="$brew";; esac
}
audit() {
  local missing=0 label command_name apt dnf pacman brew winget package version major minor
  while IFS='|' read -r label command_name apt dnf pacman brew winget; do
    [[ "$label" == \#* || -z "$label" ]] && continue
    select_package
    if command -v "$command_name" >/dev/null 2>&1; then
      printf 'OK        %-20s %s\n' "$label" "$(command -v "$command_name")"
    elif [[ "$package" == - ]]; then printf 'N/A       %s\n' "$label"
    else printf 'MISSING   %s\n' "$label"; missing=1; fi
  done < "$root/scripts/host-tools.txt"
  if command -v cmake >/dev/null 2>&1; then
    version="$(cmake --version)"
    if [[ "$version" =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]]; then
      major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"
      if (( major < 3 || (major == 3 && minor < 26) )); then echo 'MISSING   CMake >= 3.26 (upgrade with your package manager)'; missing=1; fi
    else echo 'MISSING   Cannot determine CMake version'; missing=1; fi
  fi
  if [[ -x "$vcpkg_root/vcpkg" && -f "$vcpkg_root/scripts/buildsystems/vcpkg.cmake" ]]; then echo "OK        vcpkg: $vcpkg_root"
  else echo "MISSING   vcpkg: $vcpkg_root"; missing=1; fi
  echo 'SEPARATE  Python harness, cmake-format, gcovr, IWYU runner, Emscripten (not installed by setup)'
  for command_name in nvcc dxc; do
    if command -v "$command_name" >/dev/null 2>&1; then echo "OK        $command_name"
    else echo "SDK       $command_name (install separately if needed)"; fi
  done
  return "$missing"
}
if [[ "$mode" == --check ]]; then audit; exit $?; fi
# Native tools only; Python-dependent helpers are checked separately.
case "$manager" in
  apt) packages=(build-essential curl zip unzip tar pkg-config autoconf autoconf-archive automake libtool bc) ;;
  dnf) packages=(gcc-c++ curl zip unzip tar pkgconf-pkg-config autoconf autoconf-archive automake libtool make bc) ;;
  pacman) packages=(base-devel curl zip unzip tar pkgconf autoconf-archive bc) ;;
  brew) packages=(curl zip unzip pkgconf autoconf autoconf-archive automake libtool coreutils bash llvm) ;;
esac
while IFS='|' read -r label command_name apt dnf pacman brew winget; do
  [[ "$label" == \#* || -z "$label" ]] && continue
  select_package
  [[ "$package" != - ]] || continue
  if command -v "$command_name" >/dev/null 2>&1; then continue; fi
  seen=false
  for item in "${packages[@]}"; do [[ "$item" != "$package" ]] || seen=true; done
  if [[ "$seen" == false ]]; then packages+=("$package"); fi
done < "$root/scripts/host-tools.txt"
if [[ "$mode" == --install && "$manager" == brew ]]; then
  command -v brew >/dev/null 2>&1 || fail 'Install Homebrew first: https://brew.sh'
  xcode-select -p >/dev/null || fail 'Install Xcode Command Line Tools: xcode-select --install'
fi
# Do not introduce Python indirectly through a tool package either. If dependency
# metadata cannot be checked, skip that package rather than install blindly.
check_dependencies() {
  [[ "$mode" != --dry-run ]] || return 0
  local plan line
  case "$manager" in
    apt) plan="$(LC_ALL=C apt-get -s --no-install-recommends install "$1")" || return 1 ;;
    dnf) plan="$(dnf repoquery --requires --resolve --recursive --qf '%{name}' "$1")" || return 1 ;;
    pacman) plan="$(pacman -Sp --needed --print-format '%n' "$1")" || return 1 ;;
    brew) plan="$(brew deps --formula --include-build "$1")" || return 1 ;;
  esac
  while IFS= read -r line; do
    if [[ "$line" =~ ^Inst[[:space:]]+(python|libpython|pypy) || "$line" =~ ^(python|libpython|pypy) ]]; then
      echo "SKIPPED   $1 has a Python dependency: $line. Install/configure it separately." >&2
      return 1
    fi
  done <<< "$plan"
}
failed=0
if [[ "$manager" == apt ]]; then elevated apt-get update; fi
for package in "${packages[@]}"; do
  if ! check_dependencies "$package"; then
    echo "SKIPPED   $package: dependency preflight failed" >&2
    failed=1
    continue
  fi
  case "$manager" in
    apt) if ! elevated apt-get install -y --no-install-recommends "$package"; then failed=1; fi ;;
    dnf) if ! elevated dnf install -y --setopt=install_weak_deps=False "$package"; then failed=1; fi ;;
    pacman) if ! elevated pacman -S --needed --noconfirm "$package"; then failed=1; fi ;;
    brew) if ! run brew install "$package"; then failed=1; fi ;;
  esac
done
refresh_path
if [[ ! -d "$vcpkg_root" ]]; then run git clone https://github.com/microsoft/vcpkg.git "$vcpkg_root"; fi
if [[ ! -x "$vcpkg_root/vcpkg" ]]; then run bash "$vcpkg_root/bootstrap-vcpkg.sh" -disableMetrics; fi
if [[ "$mode" == --dry-run ]]; then
  echo "Would write $tools_dir/env.sh and audit installed tools."
  exit 0
fi
mkdir -p "$tools_dir"
{
  printf 'export VCPKG_ROOT=%q\n' "$vcpkg_root"
  printf 'export PATH=%q:"$PATH"\n' "$extra_path"
} > "$tools_dir/env.sh"
printf 'Activate: source %q\n' "$tools_dir/env.sh"
if ! audit; then failed=1; fi
[[ "$failed" == 0 ]] || fail 'Setup incomplete; review package errors and missing tools above.'
