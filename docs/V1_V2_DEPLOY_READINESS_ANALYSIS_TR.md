# AOXCORE v1 (`AOXC.sol`) → v2 (`AoxcCore.sol`) Deploy Readiness Assessment

## Executive Decision

**Current recommendation: NO-GO for production upgrade.**

Reasoning:
1. `AoxcCore.sol` previously contained merge-artifact corruption patterns that can invalidate compile/runtime confidence.
2. `VerifyV1ToV2Invariants.s.sol` previously contained duplicate imports and artifact text, weakening post-upgrade assurance.
3. Foundry toolchain availability must be guaranteed in CI and release environments before final sign-off.

---

## 1) Assessment Scope

This review covers:
- v1 token implementation: `src/aoxcore-v1/AOXC.sol`
- v2 core implementation: `src/aoxcore-v2/core/AoxcCore.sol`
- rehearsal deployment script: `script/RehearseV1ToV2.s.sol`
- invariant verification script: `script/VerifyV1ToV2Invariants.s.sol`
- parity integration suite: `test/02_Integration/V1V2Parity.t.sol`
- migration runbook: `docs/MIGRATION_REHEARSAL_RUNBOOK.md`

---

## 2) Positive Signals

1. The migration runbook defines a valid operational sequence (slot checks → rehearsal deploy → invariant verification → governance sign-off).
2. Parity test design targets critical behavior classes (blacklist, transfer velocity, daily limits, pause semantics, mint limits).
3. Rehearsal script design is explicit and operator-auditable.

These are strong structural indicators for eventual production readiness.

---

## 3) Blocking Concerns

### 3.1 Source Integrity Risk in Core Contract

The v2 core must be treated as release-blocked until:
- duplicate/conflicting code paths are eliminated,
- function blocks are structurally coherent,
- artifact text and dead code fragments are removed.

### 3.2 Verification Script Integrity

The post-upgrade invariant script is a governance-critical safety control and must remain clean, deterministic, and reviewable. Any artifact residue or duplicate logic is a release blocker.

### 3.3 Build and Test Determinism

Production migration cannot proceed without deterministic execution of:
- `forge build`
- `forge test`
- migration rehearsal scripts
- post-upgrade invariant checks

---

## 4) Is v2 Core Architecturally Suitable?

**Yes, architecturally. Not yet production-ready without hard validation gates.**

The design intent aligns with v1 parity goals, but production acceptance requires reproducible build/test evidence and rehearsal proof.

---

## 5) Can a Zero-Defect Upgrade Be Guaranteed Today?

**No.**

Minimum acceptance criteria before GO:
1. Core and verification script integrity fully validated.
2. `forge build` green.
3. `forge test` green, including `V1V2Parity`.
4. storage-slot uniqueness check green.
5. successful rehearsal and invariant evidence archived for governance.

---

## 6) Recommended Action Plan

### Phase A — Immediate
1. Finalize core contract cleanup and consistency review.
2. Finalize invariant script cleanup and review.
3. Pin Foundry toolchain versions in CI and release docs.

### Phase B — Validation
1. Execute full build/test matrix.
2. Run fork/testnet rehearsal and capture evidence.
3. Attach parity and invariant outputs to DAO approval packet.

### Phase C — Release Decision
1. Convene cross-functional GO/NO-GO review (engineering, security, governance).
2. Execute controlled production rollout with rollback readiness.

---

## 7) Operational Conclusion

A production upgrade should proceed only after deterministic evidence confirms code integrity, behavior parity, and post-upgrade invariants. Until then, the correct stance is **NO-GO**.
