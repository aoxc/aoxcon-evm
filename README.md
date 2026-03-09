# AOXCORE — Enterprise DAO, Security, and AI Governance Stack

AOXCORE is a modular monorepo for building an enterprise-grade governance and security platform at the intersection of blockchain protocols and AI-assisted decision systems.

The repository is organized around one strategic objective:

> Deliver a deterministic, auditable, and upgrade-safe DAO execution environment where AI can assist operations under strict policy boundaries.

---

## Repository Structure

### 1) Protocol Layer (`/src`, `/test`, `/script`)
- Upgradeable Solidity modules (UUPS + namespaced storage patterns).
- DAO governance, treasury/finance, registry, security sentinel, and auto-repair primitives.
- Foundry-based validation (unit, integration, fuzz).

### 2) Service Layer (`/backend`)
- Sentinel API for AI-assisted risk analysis.
- Structured, correlation-aware logging model.
- Validation and controller boundaries for safer request handling.

### 3) Interface Layer (`/frontend`)
- React-based operational console for governance, audit trails, and system telemetry.
- Operator-first UX for monitoring and intervention workflows.

### 4) Operator Tooling (`/cli`)
- Command-driven operational utilities.
- Lightweight process interface for audit and status flows.

### 5) Program Governance & Delivery (`/docs`, workflow files)
- Security hardening roadmap.
- Development evolution plan.
- CI guardrails for slot safety and Solidity test execution.

---

## Enterprise Design Principles

1. **Determinism before automation**
   - AI does not replace governance controls.
   - All privileged actions remain policy-gated and auditable.

2. **Upgrade safety by default**
   - Unique storage namespaces.
   - Migration rehearsal and rollout discipline.

3. **Logs as operational truth**
   - Correlation IDs across services.
   - Structured logs for incident forensics.

4. **Separation of duties**
   - Governance, audit, and upgrade permissions are role-separated.

5. **Progressive hardening**
   - CI gates, regression coverage, and explicit remediation plans.

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

### Slot Safety Gate
```bash
python script/check_storage_slots.py
```

---

## Logging and Operational Governance

AOXCORE uses structured logs to improve security and operations quality.

- Each inbound backend request receives a request ID.
- Security-sensitive flows emit explicit event categories.
- Error responses preserve operator-safe detail while logging technical context.

See:
- `docs/LOGGING_AND_OPERATIONS_STANDARD.md`
- `docs/DEVELOPMENT_FULL_EVOLUTION_PLAN.md`
- `docs/XLAYER_SUI_FULL_GATEWAY_BLUEPRINT.md`
- `docs/WEB_PUBLISH_AND_RC_CHECKLIST.md`
- `docs/WEB_PUBLISH_AND_RC_CHECKLIST.md
- `GOVERNANCE_ENTERPRISE_REFACTOR_PLAN.md`

---

## Current Focus

- v1 -> v2 migration safety (storage integrity and upgrade confidence).
- Governance correctness (quorum semantics and execution constraints).
- AI authority boundaries with full auditability.
- CI-driven quality gates for continuous hardening.

---

## License

MIT
