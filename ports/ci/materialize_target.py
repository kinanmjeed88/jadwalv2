#!/usr/bin/env python3
"""Materialize an official target branch with a Windows port patch applied.

This helper is used by the `Port Verification` workflow
(.github/workflows/port-verify.yml) so that a port can be verified on a
GitHub runner *without* pushing anything to the official branches.

Targets
-------
* ``win7``  -> ``main`` of the port patches plus ``ports/port-windows7-weekly-load.patch``
* ``win10`` -> ``ports/port-windows10-11-weekly-load.patch``
* ``feature`` -> the feature branch head (PR #132 head) with no patch applied.

Critical branch names are written with ASCII unicode escapes so the script
behaves identically on Linux and Windows runners regardless of console
encoding.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]

TARGETS = {
    "win7": {
        "branch": "\u0628\u0631\u0646\u0627\u0645\u062c-\u0645\u062e\u0635\u0635-\u0644\u0648\u0646\u062f\u0648\u0632-\u0667",
        "patch": "ports/port-windows7-weekly-load.patch",
        "expected_tip": "b9b62154be64cb1b9cb5c6cf3063b57881aaa17d",
        "label": "Windows 7",
    },
    "win10": {
        "branch": "\u0628\u0631\u0646\u0627\u0645\u062c-\u0645\u062e\u0635\u0635-\u0644\u0648\u0646\u062f\u0648\u0632-\u0661\u0660-\u0648-\u0661\u0661",
        "patch": "ports/port-windows10-11-weekly-load.patch",
        "expected_tip": "6b253a397b64a6260b96d9d9e608b8e2dd5ec6c6",
        "label": "Windows 10 / 11",
    },
    "feature": {
        "branch": "arena/01a10437-jadwalv2",
        "patch": None,
        "expected_tip": "b522ff0fe40a03a804146ded4bff3e9b5374afcc",
        "label": "main (Android) feature head",
    },
}


def run(cmd: list[str], cwd: pathlib.Path | None = None) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=cwd, check=True, text=True, capture_output=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=sorted(TARGETS))
    parser.add_argument("destination", type=pathlib.Path)
    args = parser.parse_args()

    spec = TARGETS[args.target]
    destination = args.destination.resolve()

    if destination.exists():
        raise SystemExit(f"destination already exists: {destination}")

    refspec = f"+refs/heads/{spec['branch']}:refs/remotes/origin/porttarget"
    run(["git", "fetch", "--no-tags", "--depth=1", "origin", refspec], cwd=REPO_ROOT)

    tip = run(["git", "rev-parse", "refs/remotes/origin/porttarget"], cwd=REPO_ROOT).stdout.strip()
    if spec.get("expected_tip") and tip != spec["expected_tip"]:
        raise SystemExit(
            f"target tip changed: expected {spec['expected_tip']} but found {tip}. "
            "Regenerate the port patch before verifying."
        )

    run(["git", "worktree", "add", "--detach", str(destination), "refs/remotes/origin/porttarget"],
        cwd=REPO_ROOT)

    patch_rel = spec.get("patch")
    if patch_rel:
        patch_path = REPO_ROOT / patch_rel
        run(["git", "apply", "--check", str(patch_path)], cwd=destination)
        run(["git", "apply", str(patch_path)], cwd=destination)

    changed = run(["git", "status", "--short"], cwd=destination).stdout.strip().splitlines()
    summary = {
        "target": args.target,
        "label": spec["label"],
        "branch": spec["branch"],
        "tip": tip,
        "patch": patch_rel,
        "changed_files": len(changed),
        "tree": str(destination),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))

    if spec.get("patch") and len(changed) != 40:
        raise SystemExit(f"unexpected number of changed files after applying the port: {len(changed)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
