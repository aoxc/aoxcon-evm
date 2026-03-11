<div align="center">
  <img width="1200" height="475" alt="AOXCORE_Banner" src="https://github.com/user-attachments/assets/0aa67016-6eaf-458a-adb2-6e31a0763ed6" />

# AOXCORE Frontend Console
### Operator-grade interface for governance, telemetry, and security workflows

[![Status](https://img.shields.io/badge/Protocol-Active-00f2ff.svg?style=flat-square)](https://github.com/aoxc/AOXCORE)
[![Frontend](https://img.shields.io/badge/Framework-React%2019-61dafb.svg?style=flat-square)](https://react.dev/)
[![Build](https://img.shields.io/badge/Tooling-Vite-646cff.svg?style=flat-square)](https://vitejs.dev/)
[![Security](https://img.shields.io/badge/Security-Gemini%20Sentinel-8e44ad.svg?style=flat-square)](https://ai.google.dev/)

</div>

---

## Overview

The AOXCORE frontend is an operations-focused React application that exposes governance controls, migration telemetry, forensic ledger views, and AI-assisted sentinel insights in one unified control plane.

## Risk Disclosure

This frontend is in active evolution alongside protocol migration workstreams. Treat current builds as **release-candidate quality** unless explicitly tagged as production-ready by governance and security signoff.


Primary goals:
- Provide high-fidelity operational visibility over protocol state.
- Enable deterministic intervention paths for privileged actors.
- Surface migration and parity-critical signals during v1→v2 rollout windows.

---

## Technology Stack

- **Runtime/UI:** React 19 + TypeScript
- **Build System:** Vite 7
- **State Management:** Zustand
- **Data/Visualization:** TanStack Query, Recharts
- **Web3 Integration:** Ethers + Viem + Wagmi
- **Animation/UX:** Framer Motion
- **i18n:** i18next + react-i18next

---

## Local Development

### Prerequisites
- Node.js 20+
- npm 10+ (or Yarn, if your environment is configured accordingly)

### Install
```bash
cd frontend
npm install
```

### Run Development Server
```bash
npm run dev
```

### Type-check, Lint, Build
```bash
npm run type-check
npm run lint
npm run build
```

---

## Environment Variables

Copy and configure:

```bash
cp .env.example .env
```

Then provide values appropriate for your target network, RPCs, and AI integration settings.

---

## Operational Notes

1. Keep package-manager strategy consistent across local and CI environments.
2. Treat type-check and lint as release gates, not optional checks.
3. For migration periods, pair frontend release candidates with parity and invariant evidence from protocol scripts.

---

## Related Documents

- `../docs/V1_V2_PARITY_MATRIX.md`
- `../docs/MIGRATION_REHEARSAL_RUNBOOK.md`
- `../docs/WEB_PUBLISH_AND_RC_CHECKLIST.md`

