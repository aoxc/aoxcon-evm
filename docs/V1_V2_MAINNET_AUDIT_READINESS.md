# AOXC V1 → V2 Mainnet Migration and Audit Readiness (Enterprise Baseline)

## Abstract
This document defines an audit-oriented migration framework for upgrading AOXC from V1 to V2 without storage corruption, governance privilege drift, or operational regression. It is intended as a practical checklist for pre-mainnet readiness and post-upgrade assurance.

## 1. Upgrade Safety Invariants
The following invariants **must** hold across rehearsal and production upgrades:

1. **Proxy continuity**: proxy address remains unchanged after upgrade.
2. **Storage integrity**: V1 fields (`yearlyMintLimit`, `mintedThisYear`, transfer limit maps, blacklist state) remain bit-exact after V2 activation.
3. **Role integrity**: `DEFAULT_ADMIN_ROLE`, governance, sentinel, and upgrader roles are preserved or explicitly migrated according to change control.
4. **Token continuity**: `totalSupply()` and all sampled account balances are unchanged immediately after migration.
5. **Behavior continuity**: blacklist and transfer-velocity enforcement remains active before and after migration.

## 2. Recommended Migration Sequence
1. Freeze release candidate commit hash and tag it.
2. Run full test suite and static sanity checks on that hash.
3. Execute storage-slot comparison and archive output.
4. Run V1→V2 rehearsal on a fork/testnet using production-like role topology.
5. Execute post-upgrade invariant script and manually review deltas.
6. Require dual-approval signoff (engineering + security) before mainnet execution.
7. Execute upgrade through approved timelock/governance path.
8. Perform post-mainnet smoke checks and publish attestation.

## 3. Security Controls for Final Mainnet Window
- Restrict upgrade authority to hardware-backed multisig.
- Require timelock window and explicit action hash matching.
- Enforce deterministic deployment artifacts (compiler version, optimizer config, metadata policy).
- Maintain emergency rollback and incident-response runbook with clear ownership.
- Enable runtime monitoring for critical events (`Upgraded`, role changes, blacklist updates, lock toggles).

## 4. Cross-Chain Compatibility Baseline
For bridge intake defaults, V2 should explicitly support the intended ingress chain IDs at initialization. Current baseline includes:
- XLayer (`196`)
- Sui (`784`)
- Cardano (`1815`)

Any additional network onboarding should be governed via explicit governance actions and documented risk assessment.

## 5. Audit Evidence Package (Minimum)
Before mainnet go-live, archive:
- Commit hash and signed release notes.
- Storage layout reports (V1 vs V2).
- Test reports (unit/integration/fuzz) and environment details.
- Static sanity and lint outputs.
- Governance proposal payloads and execution transaction hashes.
- Post-upgrade invariant validation report.

## 6. Quality Gate (Pass/Fail)
A mainnet migration is considered **ready** only if all are true:
- No unresolved critical/high findings.
- No storage layout mismatch in audited paths.
- Rehearsal outcomes match planned behavior.
- Upgrade and rollback procedures are both executable and tested.
- Security signoff is documented and reproducible.

## 7. Practical Recommendation
Treat V1→V2 migration as a controlled protocol operation, not only a deployment step. The quality objective is not merely “successful upgrade,” but **provable continuity** of state, authority, and user-facing behavior under adversarial assumptions.
