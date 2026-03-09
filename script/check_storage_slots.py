#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "aoxcore-v2"

pattern = re.compile(
    r"bytes32\s+(?:private|internal)\s+constant\s+([A-Z0-9_]*(?:SLOT|LOCATION))\s*=\s*(0x[a-fA-F0-9]{64})"
)

# Contract-level slots (unique per contract) are more safety-relevant than library constants.
sol_files = [p for p in SRC.rglob("*.sol") if "libraries" not in p.parts]

seen = {}
duplicates = {}
for file in sol_files:
    rel = file.relative_to(ROOT)
    for i, line in enumerate(file.read_text().splitlines(), start=1):
        m = pattern.search(line)
        if not m:
            continue
        name, value = m.group(1), m.group(2).lower()
        key = (value)
        loc = f"{rel}:{i}:{name}"
        if key in seen:
            duplicates.setdefault(key, [seen[key]]).append(loc)
        else:
            seen[key] = loc

if duplicates:
    print("[FAIL] Duplicate storage slots detected in contract files:")
    for value, refs in duplicates.items():
        print(f"  {value}")
        for r in refs:
            print(f"    - {r}")
    sys.exit(1)

print(f"[OK] Unique storage slot constants across {len(sol_files)} contract files.")
