# AOXCORE Frontend Error Analysis for v1 → v2 Migration

## 1) Purpose and Scope

This report provides a structured analysis of frontend failures affecting the AOXCORE v1 → v2 transition, including root causes, operational risks, and a phased remediation program.

Scope of analysis:

- migration compatibility visibility across v1 and v2
- frontend compile, type-check, and lint failures
- environment and dependency-resolution blockers
- short-, mid-, and long-horizon remediation priorities

---

## 2) Executive Summary

1. **Primary blocker:** Frontend dependency resolution is unstable, causing TypeScript to fail on foundational modules such as `react`, `framer-motion`, and `react/jsx-runtime`.
2. **Package-management drift:** Yarn Plug'n'Play artifacts and npm-oriented scripts coexist, while installed module state remains inconsistent.
3. **Registry-policy failure:** `npm install` can fail with `403 Forbidden` for `@google/genai`, preventing deterministic dependency restoration.
4. **Signal dilution:** Until dependency resolution is repaired, high-volume TypeScript errors obscure genuine application-level defects.
5. **Positive protocol signal:** Storage-slot uniqueness checks are passing, which is a strong indicator that core upgrade-safety controls remain healthy.

---

## 3) Findings — Frontend Failure Inventory

### 3.1 Dominant Error Families

Observed during the type-check phase:

- `TS2307: Cannot find module ...`
- `TS2875: react/jsx-runtime could not be found`

Impact:

- application-level semantic validation becomes non-actionable
- type safety and CI quality gates lose practical value
- real defects become difficult to isolate

---

### 3.2 Environment and Toolchain Inconsistency

Observed state:

- npm-centric scripts are defined in `package.json`
- Yarn Plug'n'Play artifacts are present, including `.pnp.cjs`, `.pnp.loader.mjs`, and `yarn.lock`
- `node_modules` state is inconsistent or incomplete

Interpretation:

- the frontend execution model is not fully standardized
- local and CI parity risk is materially elevated
- environment-specific behavior is likely

---

### 3.3 Registry and Policy Constraints

Observed install failure pattern:

- `E403 / 403 Forbidden - GET https://registry.npmjs.org/@google%2fgenai`

Interpretation:

- the issue appears to be registry-policy or package-access related rather than a pure source-code defect
- until resolved, build, lint, and type-check pipelines cannot be considered reliable

---

## 4) Migration Linkage (v1 → v2) and Frontend Impact

The current parity analysis indicates strong alignment across core controls such as blacklist logic, transfer limits, daily controls, and mint constraints, while selected areas remain partial or gap-classified by governance design.

Frontend implications:

1. migration panels should explicitly surface `aligned`, `partial`, `gap`, and `waived` states
2. operator UX should distinguish governance-approved waivers from unresolved technical debt
3. transition screens should carry richer status semantics than simple success or failure labels
4. broken frontend quality gates reduce migration observability and increase false-confidence risk

---

## 5) Root Cause Analysis (RCA)

### RCA-1: Package-manager standard is not enforced

- **Symptom:** npm scripts coexist with Yarn Plug'n'Play artifacts and inconsistent module state
- **Outcome:** dependency resolution becomes non-deterministic across environments

### RCA-2: Registry or policy restrictions

- **Symptom:** install-time `403` on critical dependency paths such as `@google/genai`
- **Outcome:** the dependency graph cannot be restored reliably

### RCA-3: Quality gates are not layered

- **Symptom:** dependency failures create large error floods before application-level analysis can begin
- **Outcome:** debugging cost increases and real regressions are masked

### RCA-4: Weak coupling between migration evidence and UI status codes

- **Symptom:** parity semantics are documented, but not consistently projected into frontend state models
- **Outcome:** operator decision speed, confidence, and clarity degrade

---

## 6) Risk Matrix

| Risk | Severity | Impact | Likelihood | Note |
|---|---|---|---|---|
| Frontend blocked at type-check or build stage | High | High | High | Release confidence is invalid without deterministic installs |
| Local and CI behavioral divergence | High | Medium-High | High | Toolchain drift introduces non-reproducibility |
| Migration UI under-reporting parity gaps | Medium | High | Medium | Governance decisions may be misinformed |
| Gap items reaching release without formal waiver | Medium | High | Medium | Functional-scope expectations become ambiguous |

---

## 7) Phased Remediation Plan

### Phase 0 — Immediate (0–1 day)

1. enforce a single package-manager strategy across the frontend
2. resolve registry policy for blocked dependencies
3. add a pre-type-check dependency-resolution sanity gate

---

### Phase 1 — Stabilization (1–3 days)

1. restore green status for `type-check`, `lint`, and `build`
2. surface parity status codes in migration UI components
3. connect frontend error telemetry with migration events

---

### Phase 2 — Hardening (3–7 days)

1. add a CI stage dedicated to dependency resolution
2. publish migration rehearsal output into frontend dashboard telemetry
3. add a parity-evidence checkpoint into the release checklist

---

### Phase 3 — Maturity (1–2 sprints)

1. define SLI and SLO targets for type-check latency and build reliability
2. expand frontend observability with structured error classes and correlation IDs
3. enforce cross-functional release-candidate governance gates for v1 → v2 releases

---

## 8) Technical Verification Notes

Observed command outcomes during analysis:

- `python3 script/check_storage_slots.py` → pass
- `npm run type-check` (frontend) → fail due to module-resolution errors
- `npm install` (frontend) → fail with `403 Forbidden` for `@google/genai`

---

## 9) Conclusion

The principal frontend issue is not UI logic. It is dependency and environment determinism.

Operational confidence for the v1 → v2 transition requires the following sequence:

1. stable package resolution
2. reliable quality gates
3. migration-aware UI evidence
4. governance-readable operational telemetry

The passing storage-slot validation is an encouraging protocol-level signal, but frontend quality gates must be restored before migration visibility can be considered trustworthy.