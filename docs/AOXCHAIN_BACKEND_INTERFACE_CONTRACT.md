# AOXCHAIN Backend ↔ AOXC Library Interface Contract

This document defines a practical, backend-ready integration contract so chain nodes, deployment workers, and API services consume the AOXC contract library consistently.

## 1) Inputs backend must own

1. **Library manifest** (`src/aoxc-library/manifest/approved-modules.json`)
2. **Consumer config** (example: `configs/aoxchain.consumer.example.json`)
3. **RPC/network configuration**

## 2) Mandatory preflight checks

Run before any deployment or upgrade:

```bash
python3 script/generate_library_manifest.py
python3 script/validate_library_consumer_config.py \
  src/aoxc-library/manifest/approved-modules.json \
  configs/aoxchain.consumer.example.json
```

If preflight fails, backend must block deployment.

## 3) Deployment sequence (backend worker)

1. Deploy `AoxcModuleRegistry`.
2. Deploy `AoxcModuleFactory` with registry address.
3. Deploy/point module template implementations.
4. Register approved templates by module-type in registry.
5. For each module entry in consumer config:
   - compute/predict deterministic address,
   - call `deployModule(moduleType, salt, initData)`,
   - persist deployed address in backend state.

## 4) API-level expectations

Backend API should expose at minimum:

- `GET /library/manifest` → currently pinned manifest
- `POST /library/preflight` → validate consumer config against manifest
- `POST /library/deploy` → execute controlled deployment plan
- `GET /library/modules` → deployed module inventory

## 5) Chain compatibility contract

- only module IDs present in approved manifest may be deployed,
- each deployment uses deterministic `salt`,
- initializer payloads are explicit (`abi.encode` contract),
- backend stores manifest hash + git ref for forensic traceability.

## 6) Recommended production controls

- pin by git tag/commit SHA, never floating branch in production,
- enforce multisig/role-gated deployment operations,
- archive deployment tx hashes with module metadata,
- require preflight success and dry-run before mainnet execution.
