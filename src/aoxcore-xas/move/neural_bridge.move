module aoxcore_xas::neural_bridge {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    const E_DEADLINE_EXPIRED: u64 = 5301;
    const E_FINALITY_PENDING: u64 = 5302;
    const E_NONCE_MISMATCH: u64 = 5303;
    const E_REPLAY: u64 = 5304;
    const E_SIGNER_NOT_APPROVED: u64 = 5305;
    const E_PROOF_NOT_APPROVED: u64 = 5306;

    public struct BridgePacket has copy, drop, store {
        origin: address,
        nonce: u64,
        deadline_ms: u64,
        source_timestamp_ms: u64,
        signer: address,
        zk_proof_hash: vector<u8>,
        payload_hash: vector<u8>,
    }

    public struct BridgeAdminCap has key {
        id: UID,
    }

    public struct BridgeState has key {
        id: UID,
        next_nonce: Table<address, u64>,
        consumed: Table<vector<u8>, bool>,
        approved_signers: Table<address, bool>,
        approved_proofs: Table<vector<u8>, bool>,
        finality_buffer_ms: u64,
    }

    public fun init(ctx: &mut TxContext): (BridgeState, BridgeAdminCap) {
        (
            BridgeState {
                id: object::new(ctx),
                next_nonce: table::new(ctx),
                consumed: table::new(ctx),
                approved_signers: table::new(ctx),
                approved_proofs: table::new(ctx),
                finality_buffer_ms: 120000,
            },
            BridgeAdminCap { id: object::new(ctx) },
        )
    }

    public fun set_finality_buffer(_cap: &BridgeAdminCap, state: &mut BridgeState, buffer_ms: u64) {
        state.finality_buffer_ms = buffer_ms;
    }

    public fun approve_signer(_cap: &BridgeAdminCap, state: &mut BridgeState, signer: address) {
        if (table::contains(&state.approved_signers, signer)) {
            *table::borrow_mut(&mut state.approved_signers, signer) = true;
        } else {
            table::add(&mut state.approved_signers, signer, true);
        };
    }

    public fun approve_proof(_cap: &BridgeAdminCap, state: &mut BridgeState, proof_hash: vector<u8>) {
        if (table::contains(&state.approved_proofs, proof_hash)) {
            *table::borrow_mut(&mut state.approved_proofs, proof_hash) = true;
        } else {
            table::add(&mut state.approved_proofs, proof_hash, true);
        };
    }

    public fun verify_and_consume(
        state: &mut BridgeState,
        packet: BridgePacket,
        command_id: vector<u8>,
        now_ms: u64,
    ) {
        assert!(packet.deadline_ms >= now_ms, E_DEADLINE_EXPIRED);
        assert!(now_ms >= packet.source_timestamp_ms + state.finality_buffer_ms, E_FINALITY_PENDING);

        let expected_nonce = if (table::contains(&state.next_nonce, packet.origin)) {
            *table::borrow(&state.next_nonce, packet.origin)
        } else {
            0
        };
        assert!(packet.nonce == expected_nonce, E_NONCE_MISMATCH);

        let already = if (table::contains(&state.consumed, command_id)) {
            *table::borrow(&state.consumed, command_id)
        } else {
            false
        };
        assert!(!already, E_REPLAY);

        let signer_ok = if (table::contains(&state.approved_signers, packet.signer)) {
            *table::borrow(&state.approved_signers, packet.signer)
        } else {
            false
        };
        assert!(signer_ok, E_SIGNER_NOT_APPROVED);

        let proof_ok = if (table::contains(&state.approved_proofs, packet.zk_proof_hash)) {
            *table::borrow(&state.approved_proofs, packet.zk_proof_hash)
        } else {
            false
        };
        assert!(proof_ok, E_PROOF_NOT_APPROVED);

        // Cryptographic signature verification should be integrated with chain-native verification primitives.

        if (table::contains(&state.next_nonce, packet.origin)) {
            *table::borrow_mut(&mut state.next_nonce, packet.origin) = packet.nonce + 1;
        } else {
            table::add(&mut state.next_nonce, packet.origin, packet.nonce + 1);
        };

        table::add(&mut state.consumed, command_id, true);
    }
}
