module aoxcore::neural_bridge {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    /// Unified bridge packet representation for Sui-side validation and replay protection.
    public struct UnifiedNeuralPacket has copy, drop, store {
        command_type: u8,
        origin: address,
        target: address,
        value: u64,
        nonce: u64,
        deadline_ms: u64,
        reason_code: u16,
        risk_score: u8,
        source_chain_id: u64,
        payload_hash: vector<u8>,
        signature: vector<u8>,
    }

    /// Nonce/replay registry per origin account.
    public struct BridgeState has key {
        id: UID,
        nonces: Table<address, u64>,
        used_commands: Table<vector<u8>, bool>,
    }

    public fun init(ctx: &mut TxContext): BridgeState {
        BridgeState {
            id: object::new(ctx),
            nonces: table::new(ctx),
            used_commands: table::new(ctx),
        }
    }

    /// Placeholder verifier: signature scheme integration should be completed with Sui crypto primitives.
    /// This module already enforces nonce and replay protections at object-state level.
    public fun verify_and_consume(state: &mut BridgeState, packet: UnifiedNeuralPacket, command_id: vector<u8>, now_ms: u64) {
        assert!(packet.deadline_ms >= now_ms, 1001);

        let expected_nonce = if (table::contains(&state.nonces, packet.origin)) {
            *table::borrow(&state.nonces, packet.origin)
        } else {
            0
        };
        assert!(packet.nonce == expected_nonce, 1002);

        let used = if (table::contains(&state.used_commands, command_id)) {
            *table::borrow(&state.used_commands, command_id)
        } else {
            false
        };
        assert!(!used, 1003);

        // TODO: verify packet.signature with approved bridge signer set.

        if (table::contains(&state.nonces, packet.origin)) {
            *table::borrow_mut(&mut state.nonces, packet.origin) = packet.nonce + 1;
        } else {
            table::add(&mut state.nonces, packet.origin, packet.nonce + 1);
        };

        table::add(&mut state.used_commands, command_id, true);
    }
}
