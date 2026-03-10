<div align="center">

<a href="https://github.com/aoxc/aoxcore">
  <img src="logos/aoxc_transparent.png" alt="AOXCORE Logo" width="180" />
</a>

# 🌐 AOXCORE
### Enterprise DAO, Security, and AI Governance Stack on XLayer

[![Network](https://img.shields.io/badge/Network-XLayer%20Mainnet-blueviolet?style=for-the-badge&logo=okx)](https://www.okx.com/xlayer)
[![Security](https://img.shields.io/badge/Security-Hardening_Phase-orange?style=for-the-badge&logo=shield)](docs/SECURITY.md)
[![Status](https://img.shields.io/badge/Build-Active_Development-gold?style=for-the-badge)](docs/DEVELOPMENT_FULL_EVOLUTION_PLAN.md)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

**AOXCORE** is a modular monorepo engineered for enterprise-grade governance, security, and AI-assisted operational control on XLayer.

> **Institutional Hardening Notice**  
> This repository is currently in its **Core Hardening Phase**.  
> Architectural foundations are established while security gates, upgrade guarantees, and validation workflows are being progressively strengthened.

</div>

---

# Overview

AOXCORE provides a layered architecture for decentralized governance infrastructure combined with operational intelligence systems.

The strategic objective is explicit:

> Deliver a deterministic, auditable, and upgrade-safe DAO execution environment in which AI can assist operators under strict policy boundaries.

The system focuses on:

- upgrade-safe smart contract infrastructure
- deterministic governance execution
- AI-assisted operational analysis
- enterprise-grade monitoring and logging systems

---

# Repository Architecture

The repository is organized into layered components.

## Protocol Layer (`/src`, `/test`, `/script`)

Core on-chain logic and validation environment.

Includes:

- upgradeable Solidity modules (UUPS + namespaced storage)
- DAO governance primitives
- treasury and finance modules
- registry infrastructure
- security sentinel modules

Validation includes:

- unit testing
- integration testing
- fuzz testing
- storage layout verification

---

## Backend Layer (`/backend`)

Operational service layer for monitoring and automation.

Capabilities include:

- Sentinel risk analysis API
- structured logging pipelines
- forensic event tracking
- operator policy enforcement

---

## Frontend Layer (`/frontend`)

React-based operational console.

Features include:

- governance telemetry
- audit visibility dashboards
- protocol health monitoring
- operator workflow controls

---

## CLI Layer (`/cli`)

Command-line utilities for operators.

Includes tools for:

- state inspection
- governance interaction
- reconciliation diagnostics
- operational reporting

---

## Governance & Delivery (`/docs`)

Engineering documentation and rollout procedures.

Includes:

- migration runbooks
- security hardening plans
- engineering evolution roadmap
- CI guardrails for storage-slot safety
- XLayer + Sui legacy-honor execution plan
- AoxCore-XAS modest revolution plan

---

# Repository Structure

```
aoxcore/
│
├─ src/            # Solidity smart contracts
│  └─ aoxcore-xas/ # New XAS-centric Move + Solidity modules
├─ test/           # Foundry test suite
├─ script/         # Deployment and tooling scripts
│
├─ backend/        # Sentinel API services
├─ frontend        # Operator console
├─ cli             # Command-line operational tools
│
├─ docs            # Governance and architecture documentation
│
├─ foundry.toml
├─ package.json
└─ README.md
```

---

# Core Design Principles

### Determinism Before Automation

AI assists operational workflows but does not replace governance controls.

Privileged actions remain:

- policy gated
- attributable
- reviewable

---

### Upgrade Safety by Default

Upgrade discipline relies on:

- ERC-7201 namespaced storage
- migration rehearsal
- post-upgrade invariant verification

---

### Logs as Operational Truth

Operational reliability depends on structured logging.

Capabilities include:

- request correlation identifiers
- event categorization
- forensic reconstruction support

---

### Separation of Duties

Governance authority is distributed across distinct roles:

- governance execution
- security sentinel
- audit verification
- upgrade authorization

---

### Progressive Hardening

Security posture improves continuously through:

- CI validation gates
- regression testing
- storage-slot parity checks
- automated remediation workflows

---

# Quick Start

## Protocol Engineering

Build contracts:

```
forge build
```

Verify storage layout:

```
python script/check_storage_slots.py
```

Run tests:

```
forge test
```

Run fuzz testing:

```
forge test --fuzz
```

---

## Backend Sentinel API

```
cd backend
npm install
npm run dev
```

---

## Frontend Operational Console

```
cd frontend
npm install
npm run dev
```

---

# Security Gates

## Storage Slot Safety

```
python script/check_storage_slots.py
```

## Static Solidity Validation

```
python script/static_solidity_sanity.py
```

---

# Upgrade Model

AOXCORE contracts use the **UUPS Upgradeable Proxy pattern**.

Upgrade process includes:

1. storage layout verification
2. migration rehearsal
3. multisig governance approval
4. invariant verification after upgrade

---

# Migration Readiness References

Key operational documents:

- `docs/V1_V2_PARITY_MATRIX.md`
- `docs/MIGRATION_REHEARSAL_RUNBOOK.md`
- `script/RehearseV1ToV2.s.sol`
- `script/VerifyV1ToV2Invariants.s.sol`

---

# Logging and Observability

AOXCORE uses structured logging to support operational forensics.

Features include:

- request IDs for every backend call
- security event categorization
- operator-safe error reporting
- full forensic diagnostic context

Documentation:

- `docs/LOGGING_AND_OPERATIONS_STANDARD.md`
- `docs/DEVELOPMENT_FULL_EVOLUTION_PLAN.md`
- `docs/XLAYER_SUI_FULL_GATEWAY_BLUEPRINT.md`
- `docs/WEB_PUBLISH_AND_RC_CHECKLIST.md`
- `docs/GOVERNANCE_ENTERPRISE_REFACTOR_PLAN.md`

---

# Development Workflow

Typical development cycle:

1. implement feature
2. add tests
3. run storage validation
4. run fuzz testing
5. open pull request
6. CI validation executes

Only validated changes are merged.

---

# Contribution Guidelines

Contributions must:

- include relevant tests
- preserve upgrade safety
- follow repository coding standards
- pass CI validation

See `docs/CONTRIBUTING.md`.

---

# License

This project is licensed under the MIT License.

See the `LICENSE` file for details.

---

<div align="center">
  <sub>© 2026 AOXCORE Protocol | Secure. Auditable. Upgrade-Safe.</sub>
</div>