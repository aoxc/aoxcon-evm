module aoxcore::reputation {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    const E_ALREADY_MINTED: u64 = 2001;

    /// Honor XP is non-transferable and represents legacy contribution prestige.
    public struct HonorXP has key {
        id: UID,
        owner: address,
        amount: u64,
        multiplier_bps: u64,
    }

    public struct ReputationAdminCap has key {
        id: UID,
    }

    public struct ReputationState has key {
        id: UID,
        has_honor_xp: Table<address, bool>,
        rank_multiplier_bps: Table<address, u64>,
    }

    public fun init(ctx: &mut TxContext): (ReputationState, ReputationAdminCap) {
        (
            ReputationState {
                id: object::new(ctx),
                has_honor_xp: table::new(ctx),
                rank_multiplier_bps: table::new(ctx),
            },
            ReputationAdminCap { id: object::new(ctx) }
        )
    }

    /// One-time mint from verified XLayer v1 snapshot/proof pipeline.
    public fun mint_honor_xp(
        _cap: &ReputationAdminCap,
        state: &mut ReputationState,
        owner: address,
        amount: u64,
        multiplier_bps: u64,
        ctx: &mut TxContext
    ): HonorXP {
        let already = if (table::contains(&state.has_honor_xp, owner)) {
            *table::borrow(&state.has_honor_xp, owner)
        } else {
            false
        };
        assert!(!already, E_ALREADY_MINTED);

        table::add(&mut state.has_honor_xp, owner, true);
        table::add(&mut state.rank_multiplier_bps, owner, multiplier_bps);

        HonorXP {
            id: object::new(ctx),
            owner,
            amount,
            multiplier_bps,
        }
    }

    /// DAO vote power formula helper: base + honor multiplier.
    public fun vote_power(state: &ReputationState, owner: address, base_power: u64): u64 {
        let mult = if (table::contains(&state.rank_multiplier_bps, owner)) {
            *table::borrow(&state.rank_multiplier_bps, owner)
        } else {
            0
        };
        base_power + ((base_power * mult) / 10000)
    }
}
