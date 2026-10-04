#!/usr/bin/env python3
"""Summarize `flutter test --machine` output and fail on any failure.

Usage:
    python summarize_tests.py <machine-log> [--label <name>]

Prints the executed counts (Passed / Failed / Skipped) and a GitHub Actions
warning annotation so the numbers are visible on the run summary.
Exit code is non-zero when a test failed or when no test completed.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=pathlib.Path)
    parser.add_argument("--label", default="tests")
    args = parser.parse_args()

    passed = failed = skipped = 0
    failures: list[str] = []

    for raw in args.log.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "testDone" or event.get("hidden"):
            continue
        if event.get("skipped"):
            skipped += 1
        elif event.get("result") == "success":
            passed += 1
        else:
            failed += 1
            failures.append(event.get("testID", "unknown"))

    summary = f"Passed={passed}; Failed={failed}; Skipped={skipped}"
    print(f"::warning title=Executed test results ({args.label})::{summary}")
    print(summary)
    if failures:
        print("failed test ids: " + ", ".join(str(f) for f in failures[:20]))

    if passed == 0:
        print(f"::error title={args.label}::no completed tests recorded", file=sys.stderr)
        return 1
    if failed:
        print(f"::error title={args.label}::{summary}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
