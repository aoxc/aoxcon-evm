# Cross-Chain Ultra Hardening Plan (XLayer + Sui)

This document defines a concrete alignment plan for AOXC cross-chain behavior between:

- XLayer Solidity verifier (`AoxcBridgeVerifier`)
- Sui Move bridge module (`neural_bridge.move`)

## 1) Canonical Packet Compatibility Contract

Both chains must treat packet fields as canonical and immutable:

- `commandType`
- `origin`
- `target`
- `value`
- `nonce`
- `deadline`
- `reasonCode`
- `riskScore`
- `sourceChainId`
- `payloadHash`

### Rule
Every packet consumed on either chain must have a deterministic packet-id derived from the same semantic fields.

## 2) Deterministic Packet ID and Replay Rules

XLayer now computes packet-id with:

`keccak256(abi.encode(commandType, origin, target, nonce, payloadHash, sourceChainId))`

This avoids collisions across command classes and keeps replay prevention deterministic.

## 3) Signature Gate Hardening

On XLayer, the verifier enforces:

- EIP-712 typed-data recovery
- exact signature byte length (`65`)
- non-empty payload hash

Sui side should mirror the same strictness with the chosen Sui signature primitive and signer set.

## 4) Chain Policy Alignment

Recommended policy constraints on both sides:

- supported source chain allowlist
- per-command enable/disable switch
- governance-controlled signer rotation
- emergency pause path

## 5) Migration and Invariant Tests

Minimum invariant test matrix:

1. packet nonce increments exactly once per consume
2. replay of same packet-id is rejected
3. same nonce + same payload but different command type yields different packet-id
4. expired packet rejected on both chains
5. empty payload hash rejected
6. malformed signature length rejected (EVM side)

## 6) Operational Guidance

- Use shared runbooks for signer rotation and emergency pause.
- Log packet-id, command type, source chain and nonce for forensic parity.
- Keep integration tests in CI as merge blockers.
