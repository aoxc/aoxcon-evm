#!/usr/bin/env python3
"""Generate machine-readable AOXC library manifest for downstream chains/CLIs.

This script scans `src/aoxc-library/**` module wrappers and writes
`src/aoxc-library/manifest/approved-modules.json`.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB_DIR = ROOT / "src" / "aoxc-library"
OUT = LIB_DIR / "manifest" / "approved-modules.json"

IMPORT_RE = re.compile(r'import\s+\{(?P<symbol>[^}]+)\}\s+from\s+"(?P<path>[^"]+)";')
CONTRACT_RE = re.compile(r"contract\s+(?P<name>\w+)\s+is\s+(?P<base>\w+)")
CTOR_RE = re.compile(r"constructor\s*\((?P<args>[^)]*)\)")


@dataclass
class ModuleInfo:
    module_id: str
    file: str
    contract: str
    base_contract: str
    base_import: str
    constructor_args: list[str]


def parse_file(path: Path) -> ModuleInfo | None:
    text = path.read_text(encoding="utf-8")
    import_match = IMPORT_RE.search(text)
    contract_match = CONTRACT_RE.search(text)
    if not import_match or not contract_match:
        return None

    ctor_match = CTOR_RE.search(text)
    args: list[str] = []
    if ctor_match:
        raw = ctor_match.group("args").strip()
        if raw:
            args = [a.strip() for a in raw.split(",")]

    rel = path.relative_to(ROOT).as_posix()
    return ModuleInfo(
        module_id=path.stem.replace("Module", "").lower(),
        file=rel,
        contract=contract_match.group("name"),
        base_contract=contract_match.group("base"),
        base_import=import_match.group("path"),
        constructor_args=args,
    )


def main() -> int:
    modules: list[ModuleInfo] = []
    for fp in sorted(LIB_DIR.rglob("*Module.sol")):
        parsed = parse_file(fp)
        if parsed:
            modules.append(parsed)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": "1.0.0",
        "generated_from": "script/generate_library_manifest.py",
        "module_count": len(modules),
        "modules": [asdict(m) for m in modules],
    }
    OUT.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)} with {len(modules)} modules")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
