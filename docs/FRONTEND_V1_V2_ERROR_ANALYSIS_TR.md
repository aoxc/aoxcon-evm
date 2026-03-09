# AOXCORE Frontend Error Analysis for v1 → v2 Migration

## 1) Purpose and Scope

This report provides a structured analysis of frontend failures affecting the v1→v2 transition, including root causes, operational impact, and a phased remediation program.

Scope:
- Migration compatibility visibility (v1/v2)
- Frontend compile/type/lint failures
- Environment and dependency-resolution blockers
- Short-, mid-, and long-horizon improvements

---

## 2) Executive Summary

1. **Primary blocker:** Dependency resolution is unstable, causing TypeScript to fail on foundational modules (`react`, `framer-motion`, `react/jsx-runtime`, etc.).
2. **Package-management drift:** Yarn PnP artifacts and npm-oriented scripts coexist, while installed module state is inconsistent.
3. **Registry-policy failure:** `npm install` can fail with `403 Forbidden` for `@google/genai`, preventing deterministic dependency restoration.
4. **Signal dilution:** With unresolved dependencies, high-volume TS errors obscure genuine application-level defects.
5. **Positive protocol signal:** Storage-slot uniqueness checks are passing, indicating healthy progress on upgrade-safety fundamentals.

---

## 3) Findings — Frontend Failure Inventory

### 3.1 Dominant Error Families

Observed in type-check phase:
- `TS2307: Cannot find module ...`
- `TS2875: react/jsx-runtime ... could not be found`

Impact:
- Type safety becomes non-actionable.
- CI quality gates lose semantic value.

### 3.2 Environment and Toolchain Inconsistency

Observed state:
- npm-centric scripts in `package.json`
- Yarn PnP artifacts present (`.pnp.cjs`, `.pnp.loader.mjs`, `yarn.lock`)
- Runtime package availability inconsistent

Interpretation:
- The frontend execution model is not fully standardized.
- Local/CI parity risk is materially elevated.

### 3.3 Registry and Policy Constraints

Observed install failure pattern:
- `E403 / 403 Forbidden - GET https://registry.npmjs.org/@google%2fgenai`

Interpretation:
- The issue is policy/registry-path related rather than a pure source-code defect.
- Until resolved, build/lint/type-check pipelines remain unreliable.

---

## 4) Migration Linkage (v1→v2) and Frontend Impact

The parity matrix indicates strong alignment on core controls (blacklist, transfer limits, mint windows), while certain areas remain partial/gap by governance design.

Frontend implications:
1. Migration panels should surface `aligned/partial/gap/waived` states explicitly.
2. Operator UX should distinguish governance-approved waivers from unresolved technical debt.
3. Broken frontend gates reduce migration observability and increase false confidence risk.

---

## 5) Root Cause Analysis (RCA)

### RCA-1: Package manager standard is not enforced
- Symptom: npm scripts + Yarn PnP signals + inconsistent module state
- Outcome: Non-deterministic dependency resolution across environments

### RCA-2: Registry/policy restrictions
- Symptom: install-time `403` for critical dependency paths
- Outcome: dependency graph cannot be restored reliably

### RCA-3: Non-layered quality gates
- Symptom: dependency failures produce error floods before app-level analysis
- Outcome: debugging cost increases and real regressions are masked

### RCA-4: Weak coupling between migration evidence and UI status codes
- Symptom: parity semantics are documented but not consistently projected in UI states
- Outcome: operator decision speed and confidence degrade

---

## 6) Risk Matrix

| Risk | Severity | Impact | Likelihood | Note |
|---|---|---|---|---|
| Frontend blocked at type-check/build | High | High | High | Release confidence is invalid without deterministic installs |
| Local and CI behavioral divergence | High | Medium-High | High | Toolchain drift introduces non-reproducibility |
| Migration UI under-reporting parity gaps | Medium | High | Medium | Governance decisions may be misinformed |
| Gap items reaching release without formal waiver | Medium | High | Medium | Functional scope expectations become ambiguous |

---

## 7) Phased Remediation Plan

### Phase-0 (Immediate: 0–1 day)
1. Enforce a single package-manager strategy.
2. Resolve registry policy for blocked dependencies.
3. Add pre-type-check dependency-resolution sanity gate.

### Phase-1 (Stabilization: 1–3 days)
1. Restore green state for `type-check`, `lint`, and `build`.
2. Surface parity status codes in migration UI components.
3. Connect frontend error telemetry with migration events.

### Phase-2 (Hardening: 3–7 days)
1. Add CI stage dedicated to dependency resolution.
2. Publish rehearsal output into frontend dashboard telemetry.
3. Add parity-evidence checkpoint into release checklist.

### Phase-3 (Maturity: 1–2 sprints)
1. Define SLI/SLOs for type-check latency and build reliability.
2. Expand frontend observability with error classes and correlation IDs.
3. Enforce cross-functional RC governance gates for v1→v2 releases.

---

## 8) Verification Notes

Observed command outcomes during analysis:
- `python3 script/check_storage_slots.py` → pass
- `npm run type-check` (frontend) → fail (module resolution class)
- `npm install` (frontend) → fail (`403 Forbidden` for `@google/genai`)

---

## 9) Conclusion

The principal frontend issue is not UI logic; it is dependency and environment determinism. v1→v2 operational confidence requires package-resolution stability first, then reliable quality gates, then migration-aware UI evidence.
