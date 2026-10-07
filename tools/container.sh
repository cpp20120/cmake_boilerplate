#!/usr/bin/env bash
# Bash 3.2 (macOS) treats empty arrays as unset with nounset enabled.
set -eo pipefail

usage() {
    echo 'Usage: container.sh build|test|dev|shell|run|clean [--image NAME] [--preset NAME]'
    echo '       [--docker PATH] [--base-image NAME] [--pull] [--no-cache] [--no-build]'
    echo '       [--shell COMMAND] [-- APP_ARGS...]'
}
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:---help}
shift "$(( $# > 0 ? 1 : 0 ))"
case "$action" in
    -h|--help) usage; exit 0 ;;
    build|test|dev|shell|run|clean) ;;
    *) usage >&2; exit 2 ;;
esac
image=cmake-boilerplate
preset=app-release
engine=
base_image=
shell_command=bash
no_build=false
build_flags=()
app_args=()
while (( $# )); do
    case "$1" in
        --image|--preset|--docker|--base-image|--shell)
            if (( $# < 2 )) || [[ -z "$2" ]]; then
                echo "Missing value for $1" >&2; exit 2
            fi
            case "$1" in
                --image) image=$2 ;;
                --preset) preset=$2 ;;
                --docker) engine=$2 ;;
                --base-image) base_image=$2 ;;
                --shell) shell_command=$2 ;;
            esac
            shift 2 ;;
        --pull|--no-cache) build_flags+=("$1"); shift ;;
        --no-build) no_build=true; shift ;;
        --) shift; app_args=("$@"); break ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
if [[ "$action" != run && ${#app_args[@]} -gt 0 ]]; then
    echo 'Application arguments require the run action' >&2; exit 2
fi
if [[ -z "$engine" ]]; then
    engine=$(command -v docker || command -v podman || true)
fi
if [[ -z "$engine" ]]; then
    echo 'Docker or Podman is required' >&2; exit 1
fi
cd -- "$root"
build_image() {
    local target=$1 tag=$2
    local args=(build --target "$target" --build-arg "CMAKE_PRESET=$preset")
    if [[ -n "$base_image" ]]; then
        args+=(--build-arg "DEBIAN_IMAGE=$base_image")
    fi
    "$engine" "${args[@]}" "${build_flags[@]}" -t "$tag" "$root"
}
case "$action" in
    build) build_image runtime "$image" ;;
    test) build_image test "$image:test" ;;
    dev) build_image dev "$image:dev" ;;
    shell)
        if ! "$no_build"; then build_image dev "$image:dev"; fi
        "$engine" run --rm -it -v "$root:/workspace" -w /workspace "$image:dev" "$shell_command" ;;
    run)
        if ! "$no_build"; then build_image runtime "$image"; fi
        "$engine" run --rm "$image" "${app_args[@]}" ;;
    clean)
        result=0
        for tag in "$image" "$image:dev" "$image:test"; do
            "$engine" image rm -f "$tag" || result=$?
        done
        exit "$result" ;;
esac
