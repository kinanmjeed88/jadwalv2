#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

import pefile


def analyze(path: Path) -> dict:
    pe = pefile.PE(str(path), fast_load=False)
    imports: dict[str, list[str]] = {}
    if hasattr(pe, "DIRECTORY_ENTRY_IMPORT"):
        for entry in pe.DIRECTORY_ENTRY_IMPORT:
            dll = entry.dll.decode("ascii", errors="replace")
            symbols: list[str] = []
            for imp in entry.imports:
                if imp.name:
                    symbols.append(imp.name.decode("ascii", errors="replace"))
                else:
                    symbols.append(f"ordinal:{imp.ordinal}")
            imports[dll] = sorted(symbols)
    delay_imports: dict[str, list[str]] = {}
    if hasattr(pe, "DIRECTORY_ENTRY_DELAY_IMPORT"):
        for entry in pe.DIRECTORY_ENTRY_DELAY_IMPORT:
            dll = entry.dll.decode("ascii", errors="replace")
            symbols: list[str] = []
            for imp in entry.imports:
                if imp.name:
                    symbols.append(imp.name.decode("ascii", errors="replace"))
                else:
                    symbols.append(f"ordinal:{imp.ordinal}")
            delay_imports[dll] = sorted(symbols)
    machine = pe.FILE_HEADER.Machine
    machine_name = {0x14C: "x86", 0x8664: "x64", 0xAA64: "arm64"}.get(machine, hex(machine))
    subsystem = pe.OPTIONAL_HEADER.Subsystem
    result = {
        "path": str(path),
        "machine": machine_name,
        "image_base": hex(pe.OPTIONAL_HEADER.ImageBase),
        "subsystem": subsystem,
        "imports": imports,
        "delay_imports": delay_imports,
    }
    pe.close()
    return result


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <root> <output.json>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1])
    output = Path(sys.argv[2])
    files = sorted(p for p in root.rglob("*") if p.suffix.lower() in {".exe", ".dll"})
    results = []
    for path in files:
        try:
            results.append(analyze(path))
        except Exception as exc:  # keep audit going for malformed/non-PE files
            results.append({"path": str(path), "error": f"{type(exc).__name__}: {exc}"})
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"analyzed={len(results)} output={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
