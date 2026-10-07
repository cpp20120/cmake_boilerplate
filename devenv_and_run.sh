#!/usr/bin/env bash
# Compatibility entry point: installation requires an explicit --install.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$root/setup-host.sh" "$@"
