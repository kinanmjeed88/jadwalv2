#!/usr/bin/env python3
"""Assert that the weekly-load feature test suites really executed.

Reads a `flutter test --machine` log, collects the executed suite paths and
fails when one of the feature suites is missing. This makes the Isar migration
audit and the weekday-mapping regression audits explicit per target instead of
relying on a global pass count.

Usage:
    python assert_feature_tests.py <machine-log> [--label <name>]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

EXPECTED_SUITES = [
    "test/core/models/app_config_test.dart",
    "test/core/models/weekday_mapping_regression_test.dart",
    "test/core/models/weekly_capacity_boundary_test.dart",
    "test/core/models/weekly_load_migration_test.dart",
    "test/core/models/weekly_load_policy_test.dart",
    "test/core/services/app_backup_service_test.dart",
    "test/features/setup/first_run_setup_page_test.dart",
    "test/features/setup/domain/setup_validation_test.dart",
    "test/features/timetable/domain/usecases/weekday_excel_export_test.dart",
    "test/features/timetable/domain/usecases/weekly_load_timetable_integration_test.dart",
]

# Files that must be present in the ported tree (no test suite of their own).
REQUIRED_FIXTURES = [
    "test/fixtures/legacy_classroom.dart",
]


def normalize(path: str) -> str:
    return path.replace("\\", "/")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=pathlib.Path)
    parser.add_argument("--label", default="target")
    args = parser.parse_args()

    suites: set[str] = set()
    for raw in args.log.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "suite":
            continue
        suite = event.get("suite") or {}
        path = suite.get("path") or ""
        if path:
            suites.add(normalize(path))

    missing = [s for s in EXPECTED_SUITES if not any(s in path for path in suites)]
    if missing:
        print(
            f"::error title={args.label}::weekly-load suites missing: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    tree_root = args.log.resolve().parent
    missing_fixtures = [
        rel for rel in REQUIRED_FIXTURES if (tree_root / "test").exists() and not (tree_root / rel).exists()
    ]
    if missing_fixtures:
        print(
            f"::error title={args.label}::weekly-load fixtures missing: " + ", ".join(missing_fixtures),
            file=sys.stderr,
        )
        return 1

    ran = sorted(EXPECTED_SUITES)
    print(f"::notice title={args.label}::weekly-load suites executed ({len(ran)}): " + ", ".join(ran))
    return 0


if __name__ == "__main__":
    sys.exit(main())
