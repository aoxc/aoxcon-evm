# AOXC Standalone Contract Library Layout

This document defines a stricter, sectioned, chain-consumable contract library layout.

## Directory Contract

```text
src/aoxc-library/system/
├─ interfaces/            # global module interfaces
├─ registry/              # approved-template + deployed-module registry
├─ factory/               # deterministic module deployment
└─ modules/
   └─ examples/           # standalone reference modules
```

## New Core Building Blocks

- `IAoxcModule`: unified initializer + type/version metadata.
- `AoxcModuleRegistry`: approved implementations and deployed-module tracking.
- `AoxcModuleFactory`: clone-based deployment and registration.
- `AoxcExampleTokenModule`: fully standalone ERC20-like module.
- `AoxcExampleTreasuryModule`: standalone treasury payout module.

## Integration Rule for Downstream Chains

Downstream chain repos (e.g. `aoxchain`) should:

1. only import from approved wrappers/manifests,
2. deploy module templates once,
3. register templates in `AoxcModuleRegistry`,
4. instantiate tenant/app modules with `AoxcModuleFactory`.

## Why this helps “single dependency” architecture

- hard boundaries by module type,
- independent deployment per section,
- explicit metadata (`moduleType`, `moduleVersion`),
- deterministic addresses via create2 clones,
- clean upgrade path by swapping approved template versions in registry.
