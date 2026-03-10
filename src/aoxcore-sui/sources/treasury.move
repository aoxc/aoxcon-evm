module aoxcore::treasury {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    const E_NOT_ELIGIBLE: u64 = 3001;
    const E_NO_REWARD: u64 = 3002;

    /// Founder vault tracks cumulative reward index for legacy v1 honor members.
    public struct FounderVault has key {
        id: UID,
        eligible: Table<address, bool>,
        cumulative_reward_index: u64,
        claimed_index: Table<address, u64>,
    }

    public struct TreasuryAdminCap has key {
        id: UID,
    }

    public fun init(ctx: &mut TxContext): (FounderVault, TreasuryAdminCap) {
        (
            FounderVault {
                id: object::new(ctx),
                eligible: table::new(ctx),
                cumulative_reward_index: 0,
                claimed_index: table::new(ctx),
            },
            TreasuryAdminCap { id: object::new(ctx) }
        )
    }

    public fun register_founder(_cap: &TreasuryAdminCap, vault: &mut FounderVault, founder: address) {
        if (table::contains(&vault.eligible, founder)) {
            *table::borrow_mut(&mut vault.eligible, founder) = true;
        } else {
            table::add(&mut vault.eligible, founder, true);
        };

        if (!table::contains(&vault.claimed_index, founder)) {
            table::add(&mut vault.claimed_index, founder, vault.cumulative_reward_index);
        };
    }

    /// Called when protocol income for founders is accrued.
    public fun accrue_founder_rewards(_cap: &TreasuryAdminCap, vault: &mut FounderVault, delta_index: u64) {
        vault.cumulative_reward_index = vault.cumulative_reward_index + delta_index;
    }

    /// Returns claimable units based on index delta.
    public fun claimable(vault: &FounderVault, founder: address): u64 {
        let ok = if (table::contains(&vault.eligible, founder)) {
            *table::borrow(&vault.eligible, founder)
        } else {
            false
        };
        assert!(ok, E_NOT_ELIGIBLE);

        let last = if (table::contains(&vault.claimed_index, founder)) {
            *table::borrow(&vault.claimed_index, founder)
        } else {
            0
        };

        if (vault.cumulative_reward_index > last) {
            vault.cumulative_reward_index - last
        } else {
            0
        }
    }

    public fun claim(vault: &mut FounderVault, founder: address): u64 {
        let amount = claimable(vault, founder);
        assert!(amount > 0, E_NO_REWARD);
        *table::borrow_mut(&mut vault.claimed_index, founder) = vault.cumulative_reward_index;
        amount
    }
}
