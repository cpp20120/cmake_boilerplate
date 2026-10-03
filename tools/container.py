#!/usr/bin/env python3
"""Small Docker workflow for the boilerplate.

Docker stays outside the CMake graph.  This utility only translates a few
common developer actions into explicit docker build/run commands and forwards a
normal CMake preset to the Dockerfile.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_IMAGE = "cmake-boilerplate"


def run(command: list[str], *, check: bool = True) -> int:
    print("+", " ".join(command), flush=True)
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if check and completed.returncode:
        raise SystemExit(completed.returncode)
    return completed.returncode


def docker_build(args: argparse.Namespace, target: str, tag: str) -> None:
    command = [
        args.docker,
        "build",
        "--target",
        target,
        "--build-arg",
        f"CMAKE_PRESET={args.preset}",
    ]
    if args.base_image:
        command.extend(["--build-arg", f"DEBIAN_IMAGE={args.base_image}"])
    command.extend(["-t", tag])
    if args.pull:
        command.append("--pull")
    if args.no_cache:
        command.append("--no-cache")
    command.append(str(ROOT))
    run(command)


def cmd_build(args: argparse.Namespace) -> None:
    docker_build(args, "runtime", args.image)


def cmd_test(args: argparse.Namespace) -> None:
    docker_build(args, "test", f"{args.image}:test")


def cmd_dev(args: argparse.Namespace) -> None:
    docker_build(args, "dev", f"{args.image}:dev")


def cmd_shell(args: argparse.Namespace) -> None:
    tag = f"{args.image}:dev"
    if not args.no_build:
        docker_build(args, "dev", tag)
    command = [args.docker, "run", "--rm"]
    if sys.stdin.isatty() and sys.stdout.isatty():
        command.extend(["-it", "-e", "TERM"])
    command.extend([
        "-v",
        f"{ROOT}:/workspace",
        "-w",
        "/workspace",
        tag,
        args.shell,
    ])
    run(command)


def cmd_run(args: argparse.Namespace) -> None:
    if not args.no_build:
        docker_build(args, "runtime", args.image)
    command = [args.docker, "run", "--rm", args.image]
    application_args = list(args.application_args)
    if application_args[:1] == ["--"]:
        application_args.pop(0)
    command.extend(application_args)
    run(command)


def cmd_clean(args: argparse.Namespace) -> None:
    for tag in (args.image, f"{args.image}:dev", f"{args.image}:test"):
        run([args.docker, "image", "rm", "-f", tag], check=False)


def add_build_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--preset", default="app-release", help="CMake preset used by build/test stages")
    parser.add_argument("--base-image", help="override the Dockerfile DEBIAN_IMAGE build argument")
    parser.add_argument("--pull", action="store_true", help="refresh Docker base images")
    parser.add_argument("--no-cache", action="store_true", help="disable Docker layer cache")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--docker", default=os.environ.get("DOCKER", "docker"), help="Docker-compatible CLI")
    parser.add_argument("--image", default=DEFAULT_IMAGE, help="runtime image/tag base")
    sub = parser.add_subparsers(dest="command", required=True)

    build = sub.add_parser("build", help="build the runtime image")
    add_build_options(build)
    build.set_defaults(func=cmd_build)

    test = sub.add_parser("test", help="build and execute the Dockerfile test stage")
    add_build_options(test)
    test.set_defaults(func=cmd_test)

    dev = sub.add_parser("dev", help="build only the development/toolchain image")
    add_build_options(dev)
    dev.set_defaults(func=cmd_dev)

    shell = sub.add_parser("shell", help="open a source-mounted shell in the development image")
    add_build_options(shell)
    shell.add_argument("--no-build", action="store_true", help="reuse an existing :dev image")
    shell.add_argument("--shell", default="bash")
    shell.set_defaults(func=cmd_shell)

    app = sub.add_parser("run", help="run the installed sample application image")
    add_build_options(app)
    app.add_argument("--no-build", action="store_true", help="reuse an existing runtime image")
    app.add_argument("application_args", nargs=argparse.REMAINDER, help="arguments after -- are passed to the application")
    app.set_defaults(func=cmd_run)

    clean = sub.add_parser("clean", help="remove images managed by this utility")
    clean.set_defaults(func=cmd_clean)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
