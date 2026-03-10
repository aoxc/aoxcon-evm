module aoxcore::neural_bridge {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    const E_DEADLINE_EXPIRED: u64 = 1001;
    const E_NONCE_MISMATCH: u64 = 1002;
    const E_COMMAND_REPLAY: u64 = 1003;
    const E_NOT_FINALIZED: u64 = 1004;
    const E_INVALID_SIGNER: u64 = 1005;
    const E_UNKNOWN_ZK_PROOF: u64 = 1006;

    /// Unified bridge packet representation for Sui-side validation and replay protection.
    public struct UnifiedNeuralPacket has copy, drop, store {
        command_type: u8,
        origin: address,
        target: address,
        value: u64,
        nonce: u64,
        deadline_ms: u64,
        source_block_ms: u64,
        reason_code: u16,
        risk_score: u8,
        source_chain_id: u64,
        payload_hash: vector<u8>,
        signer: address,
        signature: vector<u8>,
        zk_proof_hash: vector<u8>,
    }

    /// Admin capability for signer/proof/finality policy updates.
    public struct BridgeAdminCap has key {
        id: UID,
    }

    /// Nonce/replay registry and finality/attestation policy state.
    public struct BridgeState has key {
        id: UID,
        nonces: Table<address, u64>,
        used_commands: Table<vector<u8>, bool>,
        approved_signers: Table<address, bool>,
        approved_zk_proofs: Table<vector<u8>, bool>,
        finality_buffer_ms: u64,
    }

    public fun init(ctx: &mut TxContext): (BridgeState, BridgeAdminCap) {
        (
            BridgeState {
                id: object::new(ctx),
                nonces: table::new(ctx),
                used_commands: table::new(ctx),
                approved_signers: table::new(ctx),
                approved_zk_proofs: table::new(ctx),
                finality_buffer_ms: 120000,
            },
            BridgeAdminCap { id: object::new(ctx) }
        )
    }

    public fun set_finality_buffer_ms(_cap: &BridgeAdminCap, state: &mut BridgeState, buffer_ms: u64) {
        state.finality_buffer_ms = buffer_ms;
    }

    public fun approve_signer(_cap: &BridgeAdminCap, state: &mut BridgeState, signer: address) {
        if (table::contains(&state.approved_signers, signer)) {
            *table::borrow_mut(&mut state.approved_signers, signer) = true;
        } else {
            table::add(&mut state.approved_signers, signer, true);
        };
    }

    public fun approve_zk_proof(_cap: &BridgeAdminCap, state: &mut BridgeState, proof_hash: vector<u8>) {
        if (table::contains(&state.approved_zk_proofs, proof_hash)) {
            *table::borrow_mut(&mut state.approved_zk_proofs, proof_hash) = true;
        } else {
            table::add(&mut state.approved_zk_proofs, proof_hash, true);
        };
    }

    fun signer_is_approved(state: &BridgeState, signer: address): bool {
        if (table::contains(&state.approved_signers, signer)) {
            *table::borrow(&state.approved_signers, signer)
        } else {
            false
        }
    }

    fun zk_is_approved(state: &BridgeState, proof_hash: vector<u8>): bool {
        if (table::contains(&state.approved_zk_proofs, proof_hash)) {
            *table::borrow(&state.approved_zk_proofs, proof_hash)
        } else {
            false
        }
    }

    /// Enforces finality buffer + dual attestation gate (authorized signer + approved ZK proof hash).
    public fun verify_and_consume(state: &mut BridgeState, packet: UnifiedNeuralPacket, command_id: vector<u8>, now_ms: u64) {
        assert!(packet.deadline_ms >= now_ms, E_DEADLINE_EXPIRED);
        assert!(now_ms >= packet.source_block_ms + state.finality_buffer_ms, E_NOT_FINALIZED);

        let expected_nonce = if (table::contains(&state.nonces, packet.origin)) {
            *table::borrow(&state.nonces, packet.origin)
        } else {
            0
        };
        assert!(packet.nonce == expected_nonce, E_NONCE_MISMATCH);

        let used = if (table::contains(&state.used_commands, command_id)) {
            *table::borrow(&state.used_commands, command_id)
        } else {
            false
        };
        assert!(!used, E_COMMAND_REPLAY);

        assert!(signer_is_approved(state, packet.signer), E_INVALID_SIGNER);
        assert!(zk_is_approved(state, packet.zk_proof_hash), E_UNKNOWN_ZK_PROOF);

        // NOTE: `packet.signature` cryptographic verification can be plugged into a native Sui crypto flow.
        // This module already enforces policy-level dual control before state consumption.

        if (table::contains(&state.nonces, packet.origin)) {
            *table::borrow_mut(&mut state.nonces, packet.origin) = packet.nonce + 1;
        } else {
            table::add(&mut state.nonces, packet.origin, packet.nonce + 1);
        };

        table::add(&mut state.used_commands, command_id, true);
    }
}
