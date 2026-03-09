# AOXCORE v1 (`AOXC.sol`) → v2 (`AoxcCore.sol`) Deploy Readiness Assessment

## Executive Decision

**Current recommendation: NO-GO for production upgrade.**

Primary reasons:

1. `AoxcCore.sol` has shown prior merge-artifact corruption patterns that can invalidate compile-time and runtime confidence.
2. `VerifyV1ToV2Invariants.s.sol` has shown prior duplicate imports, repeated control blocks, and artifact residue, weakening post-upgrade assurance.
3. Foundry toolchain availability must be guaranteed across local, CI, and release environments before final sign-off.

---

## 1) Assessment Scope

This assessment covers the following components:

- v1 token implementation: `src/aoxcore-v1/AOXC.sol`
- v2 core implementation: `src/aoxcore-v2/core/AoxcCore.sol`
- rehearsal deployment script: `script/RehearseV1ToV2.s.sol`
- post-upgrade invariant verification script: `script/VerifyV1ToV2Invariants.s.sol`
- parity integration suite: `test/02_Integration/V1V2Parity.t.sol`
- migration runbook: `docs/MIGRATION_REHEARSAL_RUNBOOK.md`

---

## 2) Positive Signals

1. The migration runbook defines a logically valid operational sequence: storage slot checks → rehearsal deployment → invariant verification → governance sign-off.
2. The parity test suite targets critical behavioral classes, including blacklist logic, transfer limits, daily limits, pause semantics, and mint-policy behavior.
3. The rehearsal deployment flow is explicit and operator-auditable.
4. The overall v2 design direction appears aligned with the intended v1 parity objectives.

These are strong structural indicators for eventual production readiness.

---

## 3) Blocking Concerns

### 3.1 Source Integrity Risk in `AoxcCore.sol`

The v2 core implementation must remain release-blocked until source integrity is fully validated.

Observed or previously identified risk patterns include:

- duplicate constant definitions
- duplicate or partially duplicated function blocks
- conflicting code paths
- merge-artifact residue embedded as plain text
- dead fragments that reduce reviewability

Examples of high-risk artifact classes previously noted include repeated constants such as:

- `YEAR_SECONDS`
- `HARD_CAP_INFLATION_BPS`
- `V1_PARITY_ANCHOR_SUPPLY`

and structurally duplicated or partially broken functions such as:

- `setCriticalAddress`
- `setNeuralProtectMode`

Any such condition is a production blocker.

---

### 3.2 Verification Script Integrity Risk

The post-upgrade invariant verification script is a governance-critical safety control.

It must remain:

- clean
- deterministic
- reviewable
- free from duplicate logic
- free from artifact residue

Previously identified failure patterns include:

- duplicate imports
- repeated control logic
- merge-artifact residue inserted into script text

Any integrity issue in this script is a release blocker because it weakens post-upgrade assurance.

---

### 3.3 Build and Test Determinism

Production migration cannot proceed without deterministic execution of the following controls:

- `forge build`
- `forge test`
- migration rehearsal scripts
- post-upgrade invariant checks
- parity integration tests

If the toolchain is unavailable or inconsistent in local or CI environments, release evidence cannot be considered complete.

---

## 4) Is the v2 Core Architecturally Suitable?

**Yes, architecturally. Not yet production-ready without hard validation gates.**

The current design intent appears broadly aligned with:

- v1 parity expectations
- role-model continuity
- transfer and blacklist controls
- pause semantics
- mint policy preservation

However, architectural suitability is not equivalent to deployment readiness.

Production acceptance requires reproducible build, test, and rehearsal evidence.

---

## 5) Can a Zero-Defect Upgrade Be Guaranteed Today?

**No.**

A zero-defect production upgrade cannot be responsibly claimed under the current validation state.

Minimum acceptance criteria before a GO decision:

1. `AoxcCore.sol` integrity fully validated
2. `VerifyV1ToV2Invariants.s.sol` integrity fully validated
3. `forge build` green
4. `forge test` green, including `V1V2Parity`
5. storage-slot uniqueness check green
6. successful rehearsal evidence captured on fork or testnet
7. post-upgrade invariant evidence archived for governance approval

---

## 6) Recommended Action Plan

### Phase A — Immediate

1. Finalize `AoxcCore.sol` cleanup and structural consistency review.
2. Finalize `VerifyV1ToV2Invariants.s.sol` cleanup and review.
3. Pin Foundry toolchain versions in CI and release documentation.
4. Ensure all release-critical scripts are free from duplicate or dead code.

---

### Phase B — Validation

1. Execute the full build and test matrix.
2. Run fork or testnet rehearsal and capture evidence.
3. Execute the post-upgrade invariant verification flow.
4. Attach parity and invariant outputs to the DAO approval packet.

---

### Phase C — Release Decision

1. Convene a cross-functional GO / NO-GO review across engineering, security, and governance.
2. Approve production rollout only if all validation artifacts are complete and reproducible.
3. Execute a controlled production upgrade with active monitoring and rollback readiness.

---

## 7) Operational Conclusion

A production upgrade should proceed only after deterministic evidence confirms:

- source integrity
- behavioral parity
- storage safety
- successful rehearsal execution
- post-upgrade invariant correctness

Until then, the correct operational stance is:

**NO-GO**

---

## 8) Final Readiness Position

The v2 implementation may be directionally correct from an architectural perspective, but current readiness depends on evidence, not intent.

The proper release sequence is:

1. clean the source
2. restore deterministic build and test execution
3. complete migration rehearsal
4. verify invariants
5. obtain governance sign-off
6. execute controlled rollout

Until that chain is complete, production deployment should remain blocked.