module aoxcore_xas::honor_logic {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    const E_ALREADY_REGISTERED: u64 = 5001;

    /// Non-transferable honor profile mapped from verified XLayer v1 balance snapshots.
    public struct HonorXP has key {
        id: UID,
        owner: address,
        xlayer_v1_balance: u64,
        xp_points: u64,
    }

    public struct HonorAdminCap has key {
        id: UID,
    }

    public struct HonorState has key {
        id: UID,
        registered: Table<address, bool>,
        xp_bps_multiplier: Table<address, u64>,
    }

    public fun init(ctx: &mut TxContext): (HonorState, HonorAdminCap) {
        (
            HonorState {
                id: object::new(ctx),
                registered: table::new(ctx),
                xp_bps_multiplier: table::new(ctx),
            },
            HonorAdminCap { id: object::new(ctx) },
        )
    }

    /// v1 -> Honor XP mapping hook. Caller must provide verified snapshot proof upstream.
    public fun register_legacy_holder(
        _cap: &HonorAdminCap,
        state: &mut HonorState,
        owner: address,
        xlayer_v1_balance: u64,
        xp_points: u64,
        multiplier_bps: u64,
        ctx: &mut TxContext,
    ): HonorXP {
        let exists = if (table::contains(&state.registered, owner)) {
            *table::borrow(&state.registered, owner)
        } else {
            false
        };
        assert!(!exists, E_ALREADY_REGISTERED);

        table::add(&mut state.registered, owner, true);
        table::add(&mut state.xp_bps_multiplier, owner, multiplier_bps);

        HonorXP {
            id: object::new(ctx),
            owner,
            xlayer_v1_balance,
            xp_points,
        }
    }

    public fun governance_weight(state: &HonorState, owner: address, base_weight: u64): u64 {
        let bps = if (table::contains(&state.xp_bps_multiplier, owner)) {
            *table::borrow(&state.xp_bps_multiplier, owner)
        } else {
            0
        };
        base_weight + ((base_weight * bps) / 10000)
    }
}
