# AOXCORE Web Publish & Release Candidate Checklist

## 1) Infrastructure
- [ ] Frontend production build succeeds.
- [ ] Backend health endpoint reachable from deployment environment.
- [ ] Environment variables set (API URL, auth token, network IDs).

## 2) Security Gates
- [ ] `python script/check_storage_slots.py` passes.
- [ ] Foundry test suite passes in CI.
- [ ] No critical/high findings in dependency scan.

## 3) Operational Readiness
- [ ] CLI preflight and rehearse commands return healthy status.
- [ ] Migration rehearsal runbook completed in staging.
- [ ] Invariant verifier script executed with expected roles.

## 4) Governance Readiness
- [ ] DAO sign-off on bridge policy and emergency commands.
- [ ] Risk downgrade policy includes timelock/approval path.
- [ ] Incident rollback plan documented and reviewed.
