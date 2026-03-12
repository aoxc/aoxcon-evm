#!/usr/bin/env python3
"""AOXCORE v1->v2 production preflight.

Runs deterministic local checks and reports GO/NO-GO with actionable gaps.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass
class CheckResult:
    name: str
    status: str  # PASS / WARN / FAIL
    detail: str


def run_cmd(name: str, cmd: list[str], cwd: Path = ROOT) -> CheckResult:
    try:
        proc = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)
    except Exception as exc:  # pragma: no cover
        return CheckResult(name, 'FAIL', f'command error: {exc}')

    if proc.returncode == 0:
        return CheckResult(name, 'PASS', proc.stdout.strip() or 'ok')

    detail = (proc.stderr.strip() or proc.stdout.strip() or f'exit={proc.returncode}')
    return CheckResult(name, 'FAIL', detail)


def check_file(path: Path, name: str) -> CheckResult:
    return CheckResult(name, 'PASS' if path.exists() else 'FAIL', str(path.relative_to(ROOT)))


def check_frontend_policy() -> CheckResult:
    pkg = ROOT / 'frontend' / 'package.json'
    data = json.loads(pkg.read_text())
    deps = data.get('dependencies', {})
    dev_deps = data.get('devDependencies', {})
    blocked = sorted([p for p in {**deps, **dev_deps} if p.startswith('@')])
    if blocked:
        return CheckResult(
            'frontend_registry_policy',
            'WARN',
            'Scoped npm packages detected; restricted registries may block install: ' + ', '.join(blocked[:8]),
        )
    return CheckResult('frontend_registry_policy', 'PASS', 'No scoped npm package detected.')


def main() -> int:
    results: list[CheckResult] = []

    results.append(check_file(ROOT / 'src' / 'aoxcore-v1' / 'AOXC.sol', 'v1_contract_exists'))
    results.append(check_file(ROOT / 'src' / 'aoxcore-v2' / 'core' / 'AoxcCore.sol', 'v2_core_exists'))
    results.append(check_file(ROOT / 'script' / 'RehearseV1ToV2.s.sol', 'migration_rehearsal_script'))
    results.append(check_file(ROOT / 'script' / 'VerifyV1ToV2Invariants.s.sol', 'migration_invariant_script'))

    results.append(run_cmd('static_solidity_sanity', [sys.executable, 'script/static_solidity_sanity.py']))
    results.append(run_cmd('storage_slot_uniqueness', [sys.executable, 'script/check_storage_slots.py']))

    if shutil.which('forge'):
        results.append(run_cmd('forge_build', ['forge', 'build']))
    else:
        results.append(CheckResult('forge_build', 'WARN', 'forge binary is not installed in this environment'))

    results.append(check_frontend_policy())
    results.append(check_file(ROOT / 'backend' / 'eslint.config.cjs', 'backend_eslint_flat_config'))
    results.append(check_file(ROOT / 'frontend' / 'eslint.config.cjs', 'frontend_eslint_flat_config'))

    rank = {'PASS': 0, 'WARN': 1, 'FAIL': 2}
    final = 'GO' if max(rank[r.status] for r in results) == 0 else 'NO-GO'

    print(f'\n=== AOXCORE V1->V2 PREFLIGHT: {final} ===')
    for r in results:
        marker = {'PASS': '[PASS]', 'WARN': '[WARN]', 'FAIL': '[FAIL]'}[r.status]
        print(f'{marker} {r.name}: {r.detail}')

    return 0 if final == 'GO' else 1


if __name__ == '__main__':
    raise SystemExit(main())
