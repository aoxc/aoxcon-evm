# Strategic Analysis: `AoxcCore` <-> `AoxcSentinel`

## Goal
Provide audit-oriented logic-risk analysis for the hybrid migration architecture and selective neural transfer controls.

## 1) Core Logic Findings

### Finding A — Stale permit risk (resolved)
- **Scenario**: A critical account prepares a neural permit, then uses it much later under changed risk posture.
- **Risk**: replay window beyond intended security context.
- **Mitigation implemented**:
  - permit now stores an expiry (`packet.deadline`),
  - transfer path enforces permit expiry and consumes permit nonce.

### Finding B — Paused/sealed interception writes (resolved)
- **Scenario**: Sentinel is paused/sealed but interception writes still execute.
- **Risk**: inconsistent emergency state transitions.
- **Mitigation implemented**:
  - `processInterception` now rejects calls when paused/sealed.

### Finding C — Neural mode false-positive lock
- **Scenario**: user marked critical but unaware of permit requirement.
- **Risk**: operational transfer friction.
- **Current control**:
  - explicit admin/user mode controls (`setCriticalAddress`, `setNeuralProtectMode`),
  - deterministic revert errors with machine-readable semantics.

## 2) Gas / Cost Design Notes
- Hybrid socket keeps default path cheap:
  - no extra signature checks for normal users.
- Permit checks run only in protected mode.
- Recommended future micro-optimization:
  - pack `criticalAddress` and `neuralProtectOptIn` into bitmaps for hot-account sets,
  - use fixed-size keys for permit IDs to reduce ABI encoding overhead.

## 3) Access Isolation for Upcoming DAO Modules
- Keep DAO modules as role-isolated callers.
- Require per-module operation allowlists and explicit role grants.
- Ensure all cross-module writes use dedicated namespaces and avoid shared mutable globals.

## 4) Audit-Ready Checklist
- [x] Structured, specific custom errors for neural permit flows.
- [x] NatSpec added to newly introduced security control functions.
- [x] Migration rehearsal and invariant verification scripts present.
- [ ] Add fuzz tests for permit expiry + nonce race conditions.
- [ ] Add formal role invariant checks in verifier script.
