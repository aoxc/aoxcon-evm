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

The project focuses on:

- upgrade-safe smart contract infrastructure
- deterministic governance execution
- AI-assisted operational analysis under strict policy boundaries
- enterprise-grade monitoring and logging systems

The system is designed to reduce attack surface while ensuring long-term protocol maintainability.

---

# Key Capabilities

### Governance Infrastructure
DAO governance primitives designed for deterministic execution and upgrade safety.

### Security Sentinel
Automated security monitoring and anomaly detection pipelines integrated with governance workflows.

### Upgrade Discipline
Strict upgrade procedures using UUPS proxy patterns with storage integrity guarantees.

### AI Assisted Operations
AI tools assist operational analysis while remaining constrained by deterministic policy boundaries.

---

# Repository Architecture

The repository is organized into layered components.

## Protocol Layer (`/src`, `/test`, `/script`)

Contains the core smart contracts and validation framework.

Components include:

- upgradeable governance contracts
- treasury and financial primitives
- registry infrastructure
- protocol security modules
- Foundry testing environment

Testing includes:

- unit tests
- integration tests
- fuzz testing
- storage layout validation

---

## Backend Layer (`/backend`)

Operational service layer supporting monitoring, analysis, and automation.

Capabilities include:

- Sentinel risk analysis API
- structured logging pipelines
- forensic event tracking
- operator policy enforcement

---

## Frontend Layer (`/frontend`)

Operational monitoring console.

Features include:

- governance telemetry
- audit visibility dashboards
- protocol health monitoring
- operator workflow controls

---

## CLI Layer (`/cli`)

Command-line tools for protocol operators.

Tools include:

- state inspection utilities
- governance interaction tools
- reconciliation and diagnostics scripts

---

# Repository Structure

```
aoxcore/
│
├─ src/            # Solidity smart contracts
├─ test/           # Foundry test suite
├─ script/         # Deployment and tooling scripts
│
├─ backend/        # Sentinel API and monitoring services
├─ frontend/       # Operator console
├─ cli/            # Command-line operational tooling
│
├─ docs/           # Documentation and governance specs
│
├─ foundry.toml
├─ package.json
└─ README.md
```

---

# Prerequisites

Before running the project locally, ensure the following tools are installed.

- Node.js ≥ 18
- Foundry toolchain
- Git
- Python 3 (for auxiliary validation scripts)

Install Foundry:

```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

---

# Quick Start

## Protocol Engineering

```
forge build
```

Run storage validation:

```
python script/check_storage_slots.py
```

Run full test suite:

```
forge test
```

Run fuzz tests:

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

# Logging and Observability

AOXCORE uses structured logging designed for forensic analysis.

Logging features include:

- request correlation identifiers
- security event categorization
- operator-safe error reporting
- detailed forensic diagnostic logging

Logs are treated as a first-class operational artifact.

---

# Upgrade Model

AOXCORE smart contracts use the **UUPS upgradeable proxy model**.

Upgrade procedures include:

- storage layout validation
- migration rehearsal
- multisig governance approval
- post-upgrade verification

Upgrade safety is treated as a core protocol invariant.

---

# Security

Security considerations include:

- role-separated governance permissions
- upgrade authorization controls
- storage layout integrity checks
- regression testing
- fuzz testing

Security documentation is available in:

```
docs/SECURITY.md
```

Responsible disclosure guidelines are also included in the repository.

---

# Development Workflow

Typical development flow:

1. implement feature
2. add tests
3. run storage validation
4. run fuzz tests
5. open pull request
6. CI validation pipeline executes

Only verified changes are merged into the main branch.

---

# Documentation

Further documentation can be found in the `/docs` directory.

Key documents include:

- Logging & Operations Standard
- Development Evolution Plan
- XLayer Gateway Blueprint
- Release Candidate Checklist
- Governance Refactor Plan

---

# Contribution Guidelines

Contributions are welcome through pull requests.

All contributions must:

- include appropriate tests
- maintain upgrade safety guarantees
- follow repository coding standards
- pass CI validation

See `docs/CONTRIBUTING.md` for details.

---

# License

This project is licensed under the MIT License.

See the `LICENSE` file for details.

---

<div align="center">
  <sub>© 2026 AOXCORE Protocol | Secure. Auditable. Upgrade-Safe.</sub>
</div>
