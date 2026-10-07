#!/usr/bin/env bash
# Bash 3.2+ (including macOS system Bash); no Python/pip/venv bootstrap.
set -eo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
profile=dev
mode= manager= tools_dir="$root/out/host-tools" vcpkg_root="${VCPKG_ROOT:-$HOME/vcpkg}"
fail() { echo "Host setup: $*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: setup-host.sh --install|--check|--dry-run [options]
  --profile minimal|dev|ci    Tool selection (default: dev)
  --manager apt|dnf|pacman|brew  Override detection for dry-run
  --tools-dir PATH             Activation file directory (out/host-tools)
  --vcpkg-root PATH            Existing/new SDK checkout ($VCPKG_ROOT or ~/vcpkg)
The harness runs in CMake; setup does not require Python.
HELP
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install|--check|--dry-run)
      [[ -z "$mode" ]] || fail 'Choose exactly one mode.'
      mode="$1"; shift ;;
    --profile|--manager|--tools-dir|--vcpkg-root)
      [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail "Missing value for $1"
      case "$1" in --profile) profile="$2";; --manager) manager="$2";; --tools-dir) tools_dir="$2";; --vcpkg-root) vcpkg_root="$2";; esac
      shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done
[[ -n "$mode" ]] || { usage; exit 1; }
case "$profile" in minimal|dev|ci) ;; *) fail "Unknown profile: $profile";; esac
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
os="$(uname -s)"
distro="$os"
if [[ "$os" == Linux && -r /etc/os-release ]]; then
  distro="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-Linux}")"
fi
echo "Host: $distro; manager: $manager; profile: $profile; mode: $mode"
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
selected() { [[ ",$profiles," == *",$profile,"* ]]; }
tool_ready() {
  if [[ "$label" == compiler && "$manager" == brew ]]; then
    xcode-select -p >/dev/null 2>&1 && command -v c++ >/dev/null 2>&1
    return $?
  fi
  if [[ "$command_name" == @package ]]; then
    case "$manager" in
      apt) [[ "$(dpkg-query -W -f='${Status}' "$package" 2>/dev/null)" == 'install ok installed' ]] ;;
      dnf) rpm -q "$package" >/dev/null 2>&1 ;;
      pacman) pacman -Q "$package" >/dev/null 2>&1 ;;
      brew) brew list --versions "$package" >/dev/null 2>&1 ;;
    esac
    return $?
  fi
  if [[ "$manager" == brew && "$command_name" == libtoolize ]]; then
    command -v glibtoolize >/dev/null 2>&1; return $?
  fi
  command -v "$command_name" >/dev/null 2>&1 || return 1
  if [[ "$command_name" == cmake ]]; then
    local version
    version="$(cmake --version)" || return 1
    [[ "$version" =~ ([0-9]+)\.([0-9]+)\.[0-9]+ ]] || return 1
    (( BASH_REMATCH[1] > 3 || (BASH_REMATCH[1] == 3 && BASH_REMATCH[2] >= 26) )) || return 1
  fi
}
initial_ready="|"
report_tool() {
  local label="$1" ready="$2" status
  if [[ "$ready" == yes ]]; then
    status=ALREADY
    if [[ "$report_phase" == after && "$initial_ready" != *"|$label|"* ]]; then status=INSTALLED; fi
    initial_ready="$initial_ready$label|"
    ready_count=$((ready_count + 1))
    [[ "$status" != INSTALLED ]] || installed_count=$((installed_count + 1))
  else status=MISSING; missing=1; missing_count=$((missing_count + 1)); fi
  printf '%-10s %s\n' "$status" "$label"
}
report_phase=before
audit() {
  local missing=0 ready_count=0 installed_count=0 missing_count=0 label command_name apt dnf pacman brew winget profiles package
  while IFS='|' read -r label command_name apt dnf pacman brew winget profiles; do
    [[ "$label" == \#* || -z "$label" ]] && continue
    selected || continue
    select_package
    if [[ "$package" == - && "$label" != compiler ]]; then printf 'N/A       %s\n' "$label"
    elif tool_ready; then report_tool "$label" yes
    else report_tool "$label" no; fi
  done < "$root/scripts/host-tools.txt"
  if [[ -x "$vcpkg_root/vcpkg" && -f "$vcpkg_root/scripts/buildsystems/vcpkg.cmake" ]]; then report_tool vcpkg yes
  else report_tool vcpkg no; fi
  echo "Summary: already=$((ready_count - installed_count)) installed=$installed_count missing=$missing_count"
  echo 'SEPARATE  CUDA, DXC and Emscripten: install separately.'
  return "$missing"
}
if [[ "$mode" == --check ]]; then audit; exit $?; fi
audit || true
packages=()
while IFS='|' read -r label command_name apt dnf pacman brew winget profiles; do
  [[ "$label" == \#* || -z "$label" ]] && continue
  selected || continue
  select_package
  [[ "$package" != - ]] || continue
  if tool_ready; then continue; fi
  seen=false
  for item in "${packages[@]}"; do [[ "$item" != "$package" ]] || seen=true; done
  if [[ "$seen" == false ]]; then packages+=("$package"); fi
done < "$root/scripts/host-tools.txt"
if [[ "$mode" == --install && "$manager" == brew ]]; then
  command -v brew >/dev/null 2>&1 || fail 'Install Homebrew first: https://brew.sh'
  xcode-select -p >/dev/null || fail 'Install Xcode Command Line Tools: xcode-select --install'
fi
failed=0
if [[ "$manager" == apt && ${#packages[@]} -gt 0 ]]; then elevated apt-get update || failed=1; fi
for package in "${packages[@]}"; do
  case "$manager" in
    apt) if ! elevated apt-get install -y --no-install-recommends "$package"; then failed=1; fi ;;
    dnf) if ! elevated dnf install -y --setopt=install_weak_deps=False "$package"; then failed=1; fi ;;
    pacman) if ! elevated pacman -S --needed --noconfirm "$package"; then failed=1; fi ;;
    brew)
      if brew list --versions "$package" >/dev/null 2>&1; then
        if ! run brew upgrade "$package"; then failed=1; fi
      else
        if ! run brew install "$package"; then failed=1; fi
      fi ;;
  esac
done
refresh_path
if [[ ! -d "$vcpkg_root" ]]; then run git clone https://github.com/microsoft/vcpkg.git "$vcpkg_root" || failed=1; fi
if [[ ! -x "$vcpkg_root/vcpkg" ]]; then run bash "$vcpkg_root/bootstrap-vcpkg.sh" -disableMetrics || failed=1; fi
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
report_phase=after
if ! audit; then failed=1; fi
[[ "$failed" == 0 ]] || fail 'Setup incomplete; review package errors and missing tools above.'
