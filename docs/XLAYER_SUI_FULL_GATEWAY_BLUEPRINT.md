# AOXCORE Full-Gateway Blueprint (XLayer <-> Sui)

## Executive Summary
This document evaluates the proposed **"Neural State Synchronization"** strategy and converts it into an implementation-ready enterprise architecture.

Goal: Build a secure, auditable, and cost-aware interoperability fabric between XLayer (EVM) and Sui without sacrificing governance control.

---

## 1) Strategic Evaluation of Proposed Objectives

### A. Storage Bridge (Walrus Integration)
**Proposal:** keep heavy compliance payloads on Walrus; store only fingerprint on XLayer.

**Assessment:** ✅ Strong and cost-efficient.

**Recommended pattern:**
1. Canonical payload serialized as deterministic JSON/CBOR.
2. Hash payload (`SHA-256` off-chain + domain prefix).
3. Upload payload to Walrus (Sui side data layer).
4. Write only `{hash, walrusPointer, version, timestamp}` to XLayer event/state.

**Security constraints:**
- payload must be signed by an authorized data-relay key,
- hash mismatch must hard-fail finalization,
- each payload version must be immutable once committed.

---

### B. Reputation Portability
**Proposal:** sync `CitizenRecord` bi-directionally across XLayer and Sui.

**Assessment:** ⚠️ Feasible, but must be eventually-consistent with strict conflict rules.

**Recommended consistency model:**
- Source-of-truth = event stream with monotonic sequence ID.
- Last-write-wins is **not enough** for risk decisions.
- Use policy:
  - `risk escalation` = immediate,
  - `risk downgrade` = delayed + governance confirmation window.

**Mandatory guardrail:**
If Sui marks account as high-risk, XLayer must set neural-protected transfer mode or restriction synchronously at bridge finalization.

---

### C. Command & Control Bridge
**Proposal:** Sui Sentinel signals (`STOP`, `REPAIR`) affect XLayer `AoxcCore`.

**Assessment:** ✅ Powerful, but highest-risk surface.

**Recommended protocol shape:**
- Typed command envelope:
  - `commandType` (`STOP`, `REPAIR`, `UNSEAL`, ...)
  - `target`
  - `reasonCode`
  - `nonce`
  - `deadline`
  - `sourceChainId`
  - `payloadHash`
- Dual verification:
  1. source-side signer validation,
  2. destination-side replay protection (`nonce` + command hash registry).

**Governance safety:**
- Emergency `STOP` can be fast-path.
- `REPAIR` and `UNSEAL` should require policy/timelock unless break-glass mode is active.

---

### D. Audit-Ready / ZK-lean Security
**Proposal:** near ZK-grade trust.

**Assessment:** ✅ Correct direction.

**Practical phased approach:**
1. Phase-1: signed attestations + strict replay prevention + deterministic hashing.
2. Phase-2: light-client or committee attestation proofs.
3. Phase-3: zk-proof verification for cross-chain state claims.

---

## 2) Reference Enterprise Architecture

### Core Components
1. **State Relay Service** (off-chain, stateless workers)
2. **Policy Engine** (what can be synchronized, who can trigger)
3. **Command Verifier Contract (XLayer)**
4. **Command Verifier Module (Sui Move)**
5. **Evidence Store** (Walrus pointers + immutable audit log)

### Data Classes
- **Class-1 Critical**: risk flags, emergency commands, repair directives.
- **Class-2 Governance**: proposal/veto mirror metadata.
- **Class-3 Analytics**: non-critical telemetry.

Only Class-1 is eligible for immediate control-plane effects.

---

## 3) Security Requirements (Non-Negotiable)

1. End-to-end idempotency keys on all relay commands.
2. Replay protection per source-domain and per target module.
3. Deadline enforcement on every bridge command.
4. Role-isolated keys for relay, governance, and emergency actions.
5. Full event correlation (`requestId`, `commandId`, `hash`) in backend and CLI logs.

---

## 4) Frontend “Demo-to-Production” Plan

### Demo (Week 1)
- Health tiles: XLayer RPC, Sui RPC, Sentinel API, Relay worker status.
- Sync monitor: latest `CitizenRecord` sequence and drift indicator.
- Command center: dry-run `STOP/REPAIR` command simulation view.

### Pre-Production (Week 2-3)
- Signed command preview + hash visibility.
- Evidence tab: Walrus pointer + payload hash + command status timeline.
- Operator confirmation gates with role-based UI permissions.

### Production
- Canary environment first (limited accounts).
- Progressive rollout with rollback flag.
- Mandatory incident workflow links in UI.

---

## 5) Release Readiness Checklist

- [ ] Bridge command schema frozen and versioned.
- [ ] XLayer and Sui verifiers pass replay/deadline tests.
- [ ] Risk escalation sync tested in adversarial scenarios.
- [ ] CLI preflight validates both chain endpoints + backend.
- [ ] Governance sign-off with runbook evidence package.

---

## 6) Recommended Immediate Next Step

Build **Bridge Command Schema + Verifier Tests** before adding more UI complexity.
That single milestone gives the highest security return and unblocks safe demo publication.
