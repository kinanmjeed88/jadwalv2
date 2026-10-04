#!/usr/bin/env python3
"""Deliver a verified weekly-load port to an official Windows branch.

This performs, for one target, exactly the delivery steps:
create the porting branch on top of the official base, ``git apply --check``,
apply the patch, review the diff, commit, push the porting branch and open the
pull request against the official branch.

Usage examples
--------------
    python ports/apply-port.py win7 --dry-run          # checks only, no changes
    python ports/apply-port.py win7                    # branch + apply + commit
    python ports/apply-port.py win7 --push             # ... then push the branch
    python ports/apply-port.py win7 --push --pr        # ... then open the PR
    python ports/apply-port.py both --push --pr        # both Windows targets

The script never force-pushes, never merges unrelated histories, and never
touches the official branch directly: the porting branch is pushed and the PR
is opened against the official branch, leaving the maintainer in control.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import subprocess
import sys

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent / "ci"))

from materialize_target import TARGETS  # noqa: E402  (path setup above)

COMMIT_SUBJECT = "feat(weekly-load): سياسة الحِمل الأسبوعي والتوزيع اليومي للصفوف"
COMMIT_BODY = """نقل ميزة الحِمل الأسبوعي من main (b362b5c..b522ff0) إلى هذا الفرع
مع الحفاظ على إعدادات المنصة: حفظ الملفات عبر FileSaveService، اسم المنفذ
التنفيذي، إصدار Flutter الخاص بالفرع، واستبعاد اختبار المعيار.

مصدر التحقق: ports/PORTING_REPORT.md"""

PR_BODY_TEMPLATE = """<div dir="rtl">

## نقل ميزة «الحِمل الأسبوعي» إلى هذا الفرع

* الفرع الرسمي: `{branch}`
* قاعدة الفرع: `{base}`
* الرقعة المطبَّقة: `{patch}` (sha256 `{sha256}`)
* نتيجة التطبيق: 40 ملفًا (شجرة `{tree}`)

## التحقق المستقل

| الفحص | النتيجة |
|---|---|
| `flutter analyze --no-fatal-infos` | PASS (Flutter {flutter}) |
| `flutter test --machine` | **Passed=111; Failed=0; Skipped=0** |
| Windows Release (`lib/main_windows.dart`) | PASS |
| Bundle verify (`{exe}` + `data`) | PASS |
| Windows Smoke Test | PASS |
| Isar migration test | PASS (ضمن المجموعة) |
| Weekday regression + SmartAutoFix tests | PASS (ضمن المجموعة) |

تفاصيل التحقق الكاملة والأوامر في `ports/PORTING_REPORT.md` على `main`
(PR #133)، مع أدوات التحقق في `ports/ci/` وسير العمل
`.github/workflows/port-verify.yml`.

لم تُستبدل أي إعدادات خاصة بالفرع: `windows/**`، `pubspec.yaml`/`pubspec.lock`،
`.github/workflows/`، ملفات الدخول، وإعدادات المُثبِّت — كلها كما هي.

</div>
"""


def run(cmd: list[str], cwd: pathlib.Path | None = None, check: bool = True) -> subprocess.CompletedProcess:
    print("+", " ".join(cmd), flush=True)
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout.rstrip(), flush=True)
    if result.stderr:
        print(result.stderr.rstrip(), flush=True)
    if check and result.returncode != 0:
        raise SystemExit(f"command failed ({result.returncode}): {' '.join(cmd)}")
    return result


def ensure_clean_tree() -> None:
    out = run(["git", "status", "--porcelain"], cwd=REPO_ROOT).stdout.strip()
    if out:
        raise SystemExit("the working tree is not clean; commit or stash your work first")


def deliver(target: str, branch_name: str, push: bool, open_pr: bool, dry_run: bool) -> dict:
    spec = TARGETS[target]
    patch_rel = spec["patch"]
    patch_path = REPO_ROOT / patch_rel
    if not patch_path.exists():
        raise SystemExit(f"missing patch: {patch_rel}")

    sha256 = hashlib.sha256(patch_path.read_bytes()).hexdigest()

    run(["git", "fetch", "--no-tags", "origin",
         f"+refs/heads/{spec['branch']}:refs/remotes/origin/porttarget"], cwd=REPO_ROOT)
    tip = run(["git", "rev-parse", "refs/remotes/origin/porttarget"], cwd=REPO_ROOT).stdout.strip()
    if tip != spec["expected_tip"]:
        raise SystemExit(
            f"official branch moved: expected {spec['expected_tip']} but found {tip}. "
            "Regenerate the port patch and re-run the verification workflow first."
        )

    existing = run(["git", "branch", "--list", branch_name], cwd=REPO_ROOT).stdout.strip()
    if existing:
        raise SystemExit(
            f"branch {branch_name} already exists locally; delete it or use another --branch-name"
        )

    print(f"\n=== {spec['label']}: base {tip} ===")
    run(["git", "apply", "--check", str(patch_path)], cwd=REPO_ROOT)
    print("git apply --check: CLEAN")

    if dry_run:
        run(["git", "apply", "--stat", str(patch_path)], cwd=REPO_ROOT)
        print("dry run complete: nothing was created.")
        return {}

    run(["git", "checkout", "-b", branch_name, tip], cwd=REPO_ROOT)
    run(["git", "apply", str(patch_path)], cwd=REPO_ROOT)

    status = run(["git", "status", "--porcelain", "-uall"], cwd=REPO_ROOT).stdout.strip().splitlines()
    if len(status) != 40:
        raise SystemExit(f"unexpected number of changed files: {len(status)} (expected 40)")
    run(["git", "diff", "--stat"], cwd=REPO_ROOT)
    run(["git", "add", "-A"], cwd=REPO_ROOT)

    run(["git", "commit", "-m", COMMIT_SUBJECT, "-m", COMMIT_BODY], cwd=REPO_ROOT)
    commit = run(["git", "rev-parse", "HEAD"], cwd=REPO_ROOT).stdout.strip()
    tree = run(["git", "rev-parse", "HEAD^{tree}"], cwd=REPO_ROOT).stdout.strip()
    print(f"commit: {commit}\ntree: {tree}")

    if push:
        run(["git", "push", "-u", "origin", f"{branch_name}:{branch_name}"], cwd=REPO_ROOT)

    pr_url = ""
    if open_pr:
        body_path = pathlib.Path("/tmp") / f"port-{target}-pr-body.md"
        body_path.write_text(
            PR_BODY_TEMPLATE.format(
                branch=spec["branch"],
                base=tip,
                patch=patch_rel,
                sha256=sha256,
                tree=tree,
                flutter="3.16.9" if target == "win7" else "stable",
                exe="JadwalV2_Windows7.exe" if target == "win7" else "JadwalV2_Windows10_11.exe",
            ),
            encoding="utf-8",
        )
        title = f"feat(weekly-load): نقل ميزة الحِمل الأسبوعي إلى {spec['label']}"
        result = run(
            ["gh", "pr", "create", "--base", spec["branch"], "--head", branch_name,
             "--title", title, "--body-file", str(body_path)],
            cwd=REPO_ROOT,
        )
        pr_url = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ""

    return {
        "target": target,
        "branch": branch_name,
        "base": tip,
        "commit": commit,
        "tree": tree,
        "patch_sha256": sha256,
        "pushed": push,
        "pr": pr_url,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=["win7", "win10", "both"])
    parser.add_argument("--branch-name", default="", help="porting branch name (default port/weekly-load-<target>)")
    parser.add_argument("--push", action="store_true", help="push the porting branch")
    parser.add_argument("--pr", action="store_true", help="open the PR against the official branch (implies --push)")
    parser.add_argument("--dry-run", action="store_true", help="only run git apply --check")
    args = parser.parse_args()

    if args.pr:
        args.push = True
    ensure_clean_tree()

    targets = ["win7", "win10"] if args.target == "both" else [args.target]
    summary = []
    for target in targets:
        branch_name = args.branch_name or f"port/weekly-load-{target}"
        if len(targets) > 1 and args.branch_name:
            branch_name = f"{args.branch_name}-{target}"
        summary.append(deliver(target, branch_name, args.push, args.pr, args.dry_run))
        if len(targets) > 1:
            run(["git", "checkout", "arena/01a106af-jadwalv2"], cwd=REPO_ROOT)

    for entry in summary:
        if entry:
            print("\n" + " | ".join(f"{k}={v}" for k, v in entry.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
