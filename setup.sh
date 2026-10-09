#!/usr/bin/env bash
set -eo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
entry=setup.sh
source "$root/scripts/entry-options.sh"
mode=--install
[[ "$dry_run" == false ]] || mode=--dry-run
bash "$root/setup-host.sh" "$mode" --profile "$profile" --tools-dir "$tools_dir" \
  --defer-vcpkg "${host_extra[@]}"
if [[ -n "$init_name" ]]; then
  if [[ "$dry_run" == true ]]; then
    printf 'Would create %s at %s (requires empty output directory).\n' "$init_name" "$init_output"
    [[ "$setup_only" == true ]] || printf "Would configure, build, test and optionally launch %s with preset %s.\n" "$init_output" "$preset"
    exit 0
  fi
  source "$tools_dir/env.sh"
  cmake "-DNAME=$init_name" "-DOUTPUT=$init_output" -P "$root/scripts/Init.cmake"
  [[ "$setup_only" == false ]] || exit 0
  exec bash "$init_output/build.sh" "${build_args[@]}"
fi
if [[ "$setup_only" == false ]]; then
  exec bash "$root/build.sh" "${build_args[@]}"
fi
