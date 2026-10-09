"""Validate committed release metadata and prepare an independent vcpkg consumer."""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PORTS = ("library1", "library2")


def git(*args):
    return subprocess.check_output(
        ["git", "-C", str(ROOT), *args], text=True
    ).strip()


def read(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify():
    release = read("vcpkg/release.json")
    require(re.fullmatch(r"[0-9a-f]{40}", release["commit"]), "Invalid source SHA")
    require(re.fullmatch(r"[0-9a-f]{128}", release["sha512"]), "Invalid SHA512")
    require(re.fullmatch(r"[0-9a-f]{40}", release["vcpkg-baseline"]), "Invalid vcpkg baseline")
    require(re.fullmatch(r"\d+\.\d+\.\d+", release["version"]), "Invalid release version")
    require(release["tag"] == "v" + release["version"], "Release tag/version mismatch")
    baseline = read("versions/baseline.json")["default"]
    for name in PORTS:
        manifest = read(f"ports/{name}/vcpkg.json")
        version = manifest["version"]
        revision = manifest.get("port-version", 0)
        require(manifest["name"] == name, f"{name}: wrong port name")
        require(version == release["version"], f"{name}: release version mismatch")
        require(baseline[name] == {"baseline": version, "port-version": revision},
                f"{name}: baseline mismatch")
        entries = read(f"versions/{name[0]}-/{name}.json")["versions"]
        keys = [(e["version"], e.get("port-version", 0)) for e in entries]
        require(len(set(keys)) == len(keys), f"{name}: duplicate versions")
        current = [e for e in entries if (e["version"], e.get("port-version", 0)) == (version, revision)]
        require(len(current) == 1, f"{name}: missing current version")
        tree = git("rev-parse", f"HEAD:ports/{name}")
        require(current[0]["git-tree"] == tree, f"{name}: stale git-tree; run x-add-version after committing ports")
        # Validate historical objects too; a shallow checkout is insufficient.
        for entry in entries:
            historic = json.loads(git("show", f"{entry['git-tree']}:vcpkg.json"))
            require(historic["name"] == name and historic["version"] == entry["version"]
                    and historic.get("port-version", 0) == entry.get("port-version", 0),
                    f"{name}: invalid historical tree")
        port = (ROOT / f"ports/{name}/portfile.cmake").read_text(encoding="utf-8")
        for field, value in (("REPO", release["repository"]), ("REF", release["commit"]),
                             ("SHA512", release["sha512"])):
            require(re.search(r"\b" + field + r"\s+" + re.escape(value) + r"(?=[\s)])", port),
                    f"{name}: source {field} mismatch")
        source_cmake = git("show", f"{release['commit']}:lib/{name}/CMakeLists.txt")
        require(f"project({name} VERSION {version} " in source_cmake,
                f"{name}: source project version mismatch")
    print("Registry versions, git trees and source pins verified.")


def prepare(output, repository, baseline):
    require(re.fullmatch(r"[0-9a-f]{40}", baseline), "Registry baseline must be a full commit SHA")
    require(not output.exists(), "Consumer output must not already exist")
    release = read("vcpkg/release.json")
    shutil.copytree(ROOT / "tests/registry-consumer", output)
    config = {
        "default-registry": {"kind": "builtin", "baseline": release["vcpkg-baseline"]},
        "registries": [{"kind": "git", "repository": repository,
                        "baseline": baseline, "packages": list(PORTS)}],
    }
    (output / "vcpkg-configuration.json").write_text(
        json.dumps(config, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Independent consumer: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("verify")
    consumer = commands.add_parser("prepare")
    consumer.add_argument("--output", type=Path, required=True)
    consumer.add_argument("--repository", required=True)
    consumer.add_argument("--baseline", required=True)
    args = parser.parse_args()
    if args.command == "verify":
        verify()
    else:
        prepare(args.output, args.repository, args.baseline)


if __name__ == "__main__":
    main()
