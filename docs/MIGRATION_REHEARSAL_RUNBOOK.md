# AOXC v1 -> v2 Migration Rehearsal Runbook

This runbook defines a deterministic rehearsal process for migrating from `AOXC.sol` (v1) to `AoxcCore.sol` (v2).

## Objectives
- Prove upgrade safety before production rollout.
- Validate behavior parity for critical token controls.
- Generate operator evidence (logs + checkpoints) for DAO approval.

## Preconditions
1. Slot uniqueness check passes.
2. Unit/integration tests pass in CI.
3. Deployer, admin, nexus, sentinel addresses are finalized.
4. `integrityHash` is approved and immutable for the release window.

## Rehearsal Steps

### Step 1 — Static Safety Gates
```bash
python script/check_storage_slots.py
```

### Step 2 — Deploy Rehearsal (Testnet/Fork)
Use the Foundry migration script:
```bash
forge script script/RehearseV1ToV2.s.sol:RehearseV1ToV2 --rpc-url $RPC_URL --broadcast
```

### Step 3 — Post-Deploy Verification
Run invariant verifier:
```bash
forge script script/VerifyV1ToV2Invariants.s.sol:VerifyV1ToV2Invariants --rpc-url $RPC_URL
```

Verify the following invariants:
- v2 initialized with non-zero `admin/nexus/sentinel`.
- v2 `getMintPolicy()` window and limits are valid.
- Blacklist, transfer velocity, pause semantics match v1 expectations.
- Proxy admin and upgrader roles are assigned to intended actors.

### Step 4 — DAO Sign-off Package
Collect and archive:
- tx hashes,
- contract addresses,
- role grant events,
- test report + slot check report,
- parity evidence from `V1V2Parity` tests.

## Go/No-Go Criteria
- **GO** only if all parity-critical checks are green.
- **NO-GO** if any mismatch exists in mint policy, blacklist controls, or pause/transfer guards.
