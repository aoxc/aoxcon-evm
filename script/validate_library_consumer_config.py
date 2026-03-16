#!/usr/bin/env python3
"""Preflight validator for external-chain AOXC library consumption.

Checks that consumer config references approved module ids in manifest and
contains minimally valid deployment fields for chain/backend pipelines.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HEX32_RE = re.compile(r"^0x[a-fA-F0-9]{64}$")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def fail(msg: str) -> int:
    print(f"[ERROR] {msg}")
    return 1


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python3 script/validate_library_consumer_config.py <manifest.json> <consumer-config.json>")
        return 2

    manifest_path = Path(sys.argv[1])
    config_path = Path(sys.argv[2])

    if not manifest_path.exists() or not config_path.exists():
        return fail("manifest or config file does not exist")

    manifest = load_json(manifest_path)
    config = load_json(config_path)

    approved = {m["module_id"] for m in manifest.get("modules", [])}
    if not approved:
        return fail("manifest contains no modules")

    required_top = ["chain", "library", "modules"]
    for key in required_top:
        if key not in config:
            return fail(f"missing top-level field: {key}")

    if not isinstance(config["modules"], list) or len(config["modules"]) == 0:
        return fail("modules must be a non-empty list")

    for i, module in enumerate(config["modules"]):
        for f in ["module_id", "moduleTypeHex", "salt", "init"]:
            if f not in module:
                return fail(f"modules[{i}] missing field: {f}")

        module_id = module["module_id"]
        if module_id not in approved:
            return fail(f"modules[{i}].module_id is not approved: {module_id}")

        if not HEX32_RE.match(module["moduleTypeHex"]):
            return fail(f"modules[{i}].moduleTypeHex must be 32-byte hex")

        if not HEX32_RE.match(module["salt"]):
            return fail(f"modules[{i}].salt must be 32-byte hex")

        init = module["init"]
        if not isinstance(init, dict) or init.get("encoding") != "abi.encode":
            return fail(f"modules[{i}].init.encoding must be 'abi.encode'")
        if not isinstance(init.get("values"), list):
            return fail(f"modules[{i}].init.values must be an array")

    print("[OK] consumer config is compatible with approved module manifest")
    print(f"[OK] module_count={len(config['modules'])}, approved_manifest_modules={len(approved)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
