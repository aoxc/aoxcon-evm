# AOXCORE — Enterprise DAO, Security, and AI Governance Stack

AOXCORE is a modular monorepo for building an enterprise-grade governance and security platform at the intersection of blockchain protocol engineering and AI-assisted operations.

The strategic objective is explicit:

> Deliver a deterministic, auditable, and upgrade-safe DAO execution environment in which AI can assist operators under strict policy boundaries.

---

## Repository Topology

### 1) Protocol Layer (`/src`, `/test`, `/script`)
- Upgradeable Solidity modules (UUPS + namespaced storage patterns).
- DAO governance, treasury/finance, registry, sentinel controls, and auto-repair primitives.
- Foundry-first validation model (unit, integration, fuzz, and migration checks).

### 2) Service Layer (`/backend`)
- Sentinel API surface for AI-assisted risk analysis.
- Structured logging with correlation-aware traces for incident reconstruction.
- Request validation and controller boundaries designed for operational safety.

### 3) Interface Layer (`/frontend`)
- React-based operator console for governance execution, telemetry, and audit visibility.
- Monitoring-centric UX for intervention, incident triage, and policy-aware control paths.

### 4) Operator Tooling (`/cli`)
- Command-line utilities for preflight, rehearsal, and operational diagnostics.
- Lightweight controls for deterministic execution and status reporting.

### 5) Governance & Delivery (`/docs`, workflow files)
- Migration and rollout runbooks.
- Security hardening and engineering evolution plans.
- CI guardrails for storage-slot safety and regression discipline.

---

## Core Design Principles

1. **Determinism before automation**
   - AI augments operations; it does not replace governance controls.
   - Privileged actions remain policy-gated, attributable, and reviewable.

2. **Upgrade safety by default**
   - ERC-7201-style namespaced storage.
   - Migration rehearsal and post-upgrade invariant verification.

3. **Logs as operational truth**
   - Request and operation correlation IDs.
   - Structured evidence for forensic and compliance workflows.

4. **Separation of duties**
   - Distinct governance, audit, sentinel, and upgrade authorities.

5. **Progressive hardening**
   - CI gates, parity checks, and explicit remediation paths.

---

## Quick Start

### Protocol (Foundry)
```bash
forge build
forge test
```

### Backend API
```bash
cd backend
npm install
npm run dev
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

### Storage Slot Safety Gate
```bash
python script/check_storage_slots.py
```

---

## Migration Readiness References

- `docs/V1_V2_PARITY_MATRIX.md`
- `docs/MIGRATION_REHEARSAL_RUNBOOK.md`
- `script/RehearseV1ToV2.s.sol`
- `script/VerifyV1ToV2Invariants.s.sol`

---

## Logging and Operational Governance

AOXCORE uses structured logs to improve reliability, incident response quality, and post-mortem precision.

- Each inbound backend request receives a request ID.
- Security-sensitive flows emit explicit, queryable event categories.
- Error responses preserve operator-safe details while capturing technical context in logs.

Further reading:
- `docs/LOGGING_AND_OPERATIONS_STANDARD.md`
- `docs/DEVELOPMENT_FULL_EVOLUTION_PLAN.md`
- `docs/XLAYER_SUI_FULL_GATEWAY_BLUEPRINT.md`
- `docs/WEB_PUBLISH_AND_RC_CHECKLIST.md`
- `GOVERNANCE_ENTERPRISE_REFACTOR_PLAN.md`

---

## License

MIT
