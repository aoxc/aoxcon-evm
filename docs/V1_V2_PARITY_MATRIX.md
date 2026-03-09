# AOXC v1 (`AOXC.sol`) -> v2 (`AoxcCore.sol`) Parity Matrix

This document defines measurable compatibility between deployed v1 token behavior and the v2 core token layer.

## Scope
- v1 source: `src/aoxcore-v1/AOXC.sol`
- v2 source: `src/aoxcore-v2/core/AoxcCore.sol`

## Status Legend
- ✅ **Aligned**: behavior is implemented and test-covered.
- ⚠️ **Partial**: behavior exists but semantics/roles differ.
- ❌ **Gap**: no equivalent behavior yet.

## Matrix

| Capability | v1 (`AOXC`) | v2 (`AoxcCore`) | Status | Notes |
|---|---|---|---|---|
| Upgradeability pattern | UUPS | UUPS | ✅ | Both use OZ upgradeable design. |
| Blacklist sender check | Yes | Yes | ✅ | `_update` gate present in both. |
| Blacklist recipient check | Yes | Yes | ✅ | Added in v2 transfer update flow. |
| Transfer max per tx | Yes (`maxTransferAmount`) | Yes (`maxTransferAmount`) | ✅ | Admin-settable in both paths. |
| Daily transfer limit | Yes (`dailyTransferLimit`) | Yes (`dailyTransferLimit`) | ✅ | Day rollover enforcement is present. |
| Exclusion from transfer limits | Yes | Yes | ✅ | Admin-configurable in both. |
| Pause/unpause | `PAUSER_ROLE` | `SENTINEL_ROLE` | ⚠️ | Behavior aligned, role mapping differs by governance model. |
| Restriction API | `addToBlacklist/removeFromBlacklist` | `setRestrictionStatus` | ⚠️ | Different interface shape; same intent. |
| Mint governance limit cycle | Yearly inflation + hard cap | Yearly inflation + hard cap parity added | ✅ | v2 mint window/hardcap now tracks v1-style controls. |
| Rescue ERC20 | Yes (`rescueERC20`) | Not present | ❌ | Add if treasury ops parity is required. |

## Required Acceptance Criteria for “Migration Ready”
1. ✅ Storage slot uniqueness gate passes (`script/check_storage_slots.py`).
2. ✅ v1/v2 parity tests pass for all **Aligned** capabilities.
3. ⚠️ All **Partial** capabilities have explicit role-mapping and operational runbook.
4. ❌ All **Gap** capabilities are either implemented or formally waived by governance decision.

## Next Engineering Items
1. Decide and document whether `rescueERC20` should exist in v2 core or treasury module.
2. Add migration rehearsal script for v1->v2 proxy upgrade + post-upgrade invariants.
3. Expand parity suite with governance-role mapping and emergency repair interoperability checks.
