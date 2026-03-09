# AOXCORE Enterprise Refactor & Governance Modernization Plan

## 1) Strategic Objective
Create an enterprise-grade DAO operating model where:
- On-chain governance is deterministic and auditable.
- AI-assisted security/decision workflows are policy-bounded.
- Frontend, CLI, and backend act as controlled gateways to protocol authority.

## 2) Target Operating Model (TOM)
### 2.1 Governance Layers
1. **Constitution Layer** (immutable principles)
   - Mission, veto boundaries, emergency powers, and upgrade constraints.
2. **Protocol Policy Layer** (upgradeable governance policy)
   - Quorum model, timelock, role admin graph, risk thresholds.
3. **Execution Layer** (contracts + services)
   - Core / Nexus / Sentinel / AutoRepair + backend + CLI + UI.

### 2.2 AI Authority Model
- AI is **advisor + signal provider** by default.
- Any AI-originated action must pass:
  1. Signature validation (EIP-712 / actor attestation),
  2. Risk policy checks,
  3. Role or governance approval constraints,
  4. Full event trail for audits.

### 2.3 Security Roles & Separation of Duties
- `DEFAULT_ADMIN_ROLE`: break-glass and recovery only.
- `GOVERNANCE_ROLE`: approved DAO execution.
- `AUDIT_VOICE_ROLE`: audit veto and risk intervention.
- `UPGRADER_ROLE`: restricted by timelock + DAO proposal.

## 3) Technical Refactor Workstreams
### WS-1: Protocol Integrity (highest priority)
- Enforce unique ERC-7201 storage slots per contract.
- Normalize quorum logic to supply/snapshot-based computation.
- Add invariant tests for proposal lifecycle and veto outcomes.

### WS-2: AI-Controlled Security Pipeline
- Define canonical `NeuralPacket` schema versioning.
- Add replay protection consistency checks across Sentinel/Core/Repair.
- Introduce risk policy registry (updatable only via governance).

### WS-3: Service Hardening (backend/cli/frontend)
- Move all endpoints to environment-driven config.
- Add strict schema validation for all AI request/response payloads.
- Standardize authn/authz for operator actions from CLI/backend.

### WS-4: Assurance & Compliance
- Add security test matrix (unit, integration, fuzz, adversarial scenarios).
- Add release gates: lint + type-check + forge tests + policy checks.
- Add incident runbooks and postmortem templates.

## 4) Delivery Phases
### Phase A (Foundation)
- Slot uniqueness fixes, role graph review, config hardening.
- CI baseline and failing-test visibility.

### Phase B (Governance Quality)
- Quorum/voting model correction and proposal execution constraints.
- DAO lifecycle regression suite.

### Phase C (AI Delegation)
- Controlled AI capability scopes with explicit revocation.
- Real-time audit export for all AI-triggered actions.

## 5) Definition of Done (Enterprise Baseline)
- No critical storage collision risks.
- Governance math and veto semantics validated with tests.
- AI actions are policy-enforced, replay-safe, and fully observable.
- Frontend/CLI/backend are environment-safe and least-privileged.
