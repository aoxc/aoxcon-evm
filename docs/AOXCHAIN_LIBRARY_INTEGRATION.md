# AOXCHAIN ↔ AOXC Library Integration Blueprint

## Goal

Turn this repository into a **living contract library** where each module can be consumed independently by external systems (including `aoxchain`) while remaining versioned, auditable, and replaceable.

## Is it possible?

Yes — technically and operationally possible — if we enforce:

1. strict module boundaries,
2. immutable versioning/tagging policy,
3. machine-readable manifest + CLI consumption contract,
4. CI gatekeeping for compatibility and safety.

## Target Architecture

Each module is independently consumable:

- `core` → token/core logic
- `access` → gateway/access policies
- `ai` → sentinel/risk layer
- `bridge` → bridge verification
- `stake` → staking/yield
- `treasury` → vault/change
- `governance` → dao manager
- `infra` → auto-repair

### Consumption model

`aoxchain` should consume only approved wrappers under `src/aoxc-library/**` and never deep-link random internal files.

## Source of Truth

The canonical machine-readable list is:

- `src/aoxc-library/manifest/approved-modules.json`

Generated via:

```bash
python3 script/generate_library_manifest.py
```

This manifest is designed for CLI tooling and CI checks.

## Versioning & Release Contract

Recommended release flow:

1. Update modules / wrappers.
2. Regenerate manifest.
3. Run build/tests/lint.
4. Tag release (`lib-vX.Y.Z`).
5. `aoxchain` pins tag/commit SHA.

## CLI Compatibility Contract (minimum)

External CLI should validate:

- manifest exists,
- module contract names are present,
- referenced wrapper files exist,
- required constructor args are known before deployment.

## Migration Plan (Pragmatic)

### Phase 1 — Stabilize wrappers (current)
- Keep wrapper contracts thin and explicit.
- Publish approved manifest.

### Phase 2 — Add strict compatibility checks
- Add CI job that fails if manifest is stale.
- Add semver compatibility matrix for module-level changes.

### Phase 3 — Full external consumption
- `aoxchain` reads manifest directly and uses only approved wrappers.
- Replace manual address book with manifest-driven deployment/verification.

## Design Principles

- **Single source of truth**: manifest + tagged releases.
- **Module isolation**: each wrapper independently importable.
- **Backward compatibility**: avoid breaking constructor signatures without major version bump.
- **Auditability**: keep wrappers minimal, deterministic, and documented.

## Operator Notes

If a module constructor changes (e.g. governance), update:

1. wrapper contract,
2. manifest (`constructor_args`),
3. downstream deploy scripts and CLI templates.

Without these 3 updates, external integration will drift.
