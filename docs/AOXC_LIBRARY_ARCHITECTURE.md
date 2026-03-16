# AOXC Library Architecture (V2-first, V1-ready)

This repository exposes a **module-oriented Solidity library surface** designed for external integrators.

## Goals
- Keep V2 implementation contracts in place (`src/aoxcore-v2`) to avoid risky large-scale moves.
- Provide a clean, consumer-facing module entry layer under `src/aoxc-library`.
- Keep room for future V1 module onboarding without breaking current imports.

## Module layout
- `src/aoxc-library/core`
- `src/aoxc-library/treasury`
- `src/aoxc-library/ai`
- `src/aoxc-library/stake`
- `src/aoxc-library/bridge`
- `src/aoxc-library/access`
- `src/aoxc-library/governance`
- `src/aoxc-library/infra`

Each `*Module.sol` file is intentionally a thin wrapper inheriting the maintained V2 implementation.

## Import model
Foundry remappings allow concise imports:

```solidity
import {AoxcVaultModule} from "aoxc-lib-treasury/AoxcVaultModule.sol";
import {AoxcSentinelAIModule} from "aoxc-lib-ai/AoxcSentinelAIModule.sol";
```

## Evolution policy (recommended)
1. Keep module wrapper contracts minimal (no business-logic forks in wrappers).
2. Prefer additive API evolution.
3. Announce breaking moves/renames with deprecation windows.
4. Introduce semantic versioning tags for external consumers.
