#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

import pefile


def read_pe(path: Path) -> dict:
    pe = pefile.PE(str(path), fast_load=False)
    imports: dict[str, list[str]] = {}
    for attr in ("DIRECTORY_ENTRY_IMPORT", "DIRECTORY_ENTRY_DELAY_IMPORT"):
        if not hasattr(pe, attr):
            continue
        for entry in getattr(pe, attr):
            dll = entry.dll.decode("ascii", errors="replace")
            imports.setdefault(dll, [])
            for imp in entry.imports:
                name = imp.name.decode("ascii", errors="replace") if imp.name else f"ordinal:{imp.ordinal}"
                imports[dll].append(name)
    result = {
        "file": str(path),
        "machine": {0x14C: "x86", 0x8664: "x64", 0xAA64: "arm64"}.get(pe.FILE_HEADER.Machine, hex(pe.FILE_HEADER.Machine)),
        "imports": {k: sorted(set(v)) for k, v in sorted(imports.items())},
    }
    pe.close()
    return result


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <bundle> <report.json>", file=sys.stderr)
        return 2
    bundle = Path(sys.argv[1])
    output = Path(sys.argv[2])
    files = sorted(p for p in bundle.iterdir() if p.suffix.lower() in {".exe", ".dll"})
    records = []
    for path in files:
        try:
            records.append(read_pe(path))
        except Exception as exc:
            records.append({"file": str(path), "error": f"{type(exc).__name__}: {exc}"})
    local_names = {p.name.lower() for p in files}
    local_refs = []
    gethostname = []
    for rec in records:
        if "error" in rec:
            continue
        for dll, symbols in rec["imports"].items():
            dll_l = dll.lower()
            if dll_l in local_names:
                local_refs.append({"file": Path(rec["file"]).name, "dependency": dll})
            if "gethostnamew" in {s.lower() for s in symbols}:
                gethostname.append({"file": Path(rec["file"]).name, "dependency": dll, "symbol": "GetHostNameW"})
    result = {
        "bundle": str(bundle),
        "files": records,
        "local_dependency_references": local_refs,
        "gethostnamew_imports": gethostname,
        "missing_local_dependencies": [],
    }
    referenced = {x["dependency"].lower() for x in local_refs}
    # Every referenced local DLL is expected to be present. This remains explicit in the report.
    result["missing_local_dependencies"] = sorted(x for x in referenced if x not in local_names)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"files={len(records)} gethostnamew={len(gethostname)} local_refs={len(local_refs)} output={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
