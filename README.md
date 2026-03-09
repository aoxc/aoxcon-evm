<div align="center">

<a href="https://github.com/aoxc/aoxcore">
  <img src="logos/aoxc_transparent.png" alt="AOXCORE Logo" width="180">
</a>

# 🌐 AOXCORE
### Enterprise DAO, Security, and AI Governance Stack on XLayer

[![Network](https://img.shields.io/badge/Network-XLayer%20Mainnet-blueviolet?style=for-the-badge&logo=okx)](https://www.okx.com/xlayer)
[![Security](https://img.shields.io/badge/Security-Hardening_Phase-orange?style=for-the-badge&logo=shield)](docs/SECURITY.md)
[![Status](https://img.shields.io/badge/Build-Active_Development-gold?style=for-the-badge)](docs/DEVELOPMENT_FULL_EVOLUTION_PLAN.md)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

---

**AOXCORE** is a modular monorepo engineered for building enterprise-grade governance and security platforms at the intersection of blockchain protocols and AI-assisted decision systems.

> **🏛 Institutional Hardening Notice:** This repository is currently in its **Core Hardening Phase**. While the architectural foundations are established, we are progressively tightening security gates and verifying formal invariants on the XLayer ZK-Rollup. We welcome institutional collaboration during this pre-production cycle.

</div>

---

## 🏗 Repository Architecture

The stack is partitioned into distinct operational layers to ensure strict separation of concerns and a minimized attack surface:

### 1. Protocol Layer (`/src`, `/test`, `/script`)
* **Upgradeable Solidity:** UUPS (Universal Upgradeable Proxy Standard) + namespaced storage patterns for long-term storage integrity.
* **Core Primitives:** DAO governance, treasury/finance, registry, and "Security Sentinel" auto-repair modules.
* **XLayer-Native Validation:** Comprehensive Foundry suite including unit, integration, and fuzz testing optimized for L2 execution.



### 2. Intelligent Service Layer (`/backend`)
* **Sentinel API:** AI-augmented risk analysis operating within deterministic policy boundaries.
* **Forensic Logging:** Structured, correlation-aware logging model for enterprise-grade incident response.
* **Safety Boundaries:** Strict controller validation and boundary checks for all off-chain requests.

### 3. Interface Layer (`/frontend`)
* **Operational Console:** React-based telemetry for monitoring governance, audit trails, and system health.
* **Operator-First UX:** Optimized for real-time monitoring, intervention workflows, and administrative oversight.

### 4. Operator Tooling (`/cli`)
* **Command-Driven Utilities:** Operational tools for manual audit flows, system state reconciliation, and status reporting.

---

## 🛡 Enterprise Design Principles

Our methodology prioritizes **systemic stability** and **determinism** over rapid automation:

1.  **Determinism before Automation:** AI serves as a support tool; it does not replace governance controls. All privileged actions remain policy-gated and auditable.
2.  **Upgrade Safety by Default:** Unique storage namespaces and mandatory migration rehearsal discipline to prevent storage collisions.
3.  **Logs as Operational Truth:** End-to-end correlation IDs across all services for seamless forensic auditing and incident forensics.
4.  **Separation of Duties:** Governance, audit, and upgrade permissions are cryptographically role-separated.
5.  **Progressive Hardening:** CI gates for slot-safety, regression coverage, and explicit remediation plans.

---

## 🚀 Quick Start

### Protocol Engineering (Foundry)
```bash
# Build and verify storage slot safety
forge build
python script/check_storage_slots.py

# Run comprehensive test suite
forge test
Backend Sentinel API
Bash
cd backend
npm install
npm run dev
Frontend Operational Console
Bash
cd frontend
npm install
npm run dev
🔍 Logging and Operational Governance
AOXCORE utilizes structured, high-fidelity logging to ensure institutional-grade security:

Request Tracking: Every inbound backend request is assigned a unique Request ID.

Event Categorization: Security-sensitive flows emit explicit event categories for real-time monitoring.

Technical Context: Error responses preserve operator-safe detail while logging technical context for forensics.

Strategic Documentation:

📑 Logging & Operations Standard

📊 Development Evolution Plan

📐 XLayer Gateway Blueprint

✅ Release Candidate Checklist

⚖️ Enterprise Governance Refactor Plan

🎯 Current Engineering Focus
v1 → v2 Migration Safety: Ensuring storage integrity and upgrade confidence during network-wide transitions on XLayer.

Governance Correctness: Refining quorum semantics and deterministic execution constraints.

AI Authority Sandboxing: Establishing auditable boundaries for AI-assisted operations under strict policy gates.

CI-Driven Hardening: Automating security gates for continuous protocol validation and regression testing.

<div align="center">
<sub>© 2026 AOXCORE Protocol | Secure. Auditable. Upgrade-Safe.</sub>
</div>
