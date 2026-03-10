module aoxcore_xas::founder_vault {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    const E_INELIGIBLE: u64 = 5101;
    const E_NOTHING_TO_CLAIM: u64 = 5102;

    public struct FounderVault has key {
        id: UID,
        founders: Table<address, bool>,
        cumulative_index: u64,
        last_claimed_index: Table<address, u64>,
    }

    public struct FounderVaultAdminCap has key {
        id: UID,
    }

    public fun init(ctx: &mut TxContext): (FounderVault, FounderVaultAdminCap) {
        (
            FounderVault {
                id: object::new(ctx),
                founders: table::new(ctx),
                cumulative_index: 0,
                last_claimed_index: table::new(ctx),
            },
            FounderVaultAdminCap { id: object::new(ctx) },
        )
    }

    public fun add_founder(_cap: &FounderVaultAdminCap, vault: &mut FounderVault, founder: address) {
        if (table::contains(&vault.founders, founder)) {
            *table::borrow_mut(&mut vault.founders, founder) = true;
        } else {
            table::add(&mut vault.founders, founder, true);
        };

        if (!table::contains(&vault.last_claimed_index, founder)) {
            table::add(&mut vault.last_claimed_index, founder, vault.cumulative_index);
        };
    }

    public fun accrue(_cap: &FounderVaultAdminCap, vault: &mut FounderVault, index_delta: u64) {
        vault.cumulative_index = vault.cumulative_index + index_delta;
    }

    public fun claimable(vault: &FounderVault, founder: address): u64 {
        let eligible = if (table::contains(&vault.founders, founder)) {
            *table::borrow(&vault.founders, founder)
        } else {
            false
        };
        assert!(eligible, E_INELIGIBLE);

        let last = if (table::contains(&vault.last_claimed_index, founder)) {
            *table::borrow(&vault.last_claimed_index, founder)
        } else {
            0
        };

        if (vault.cumulative_index > last) {
            vault.cumulative_index - last
        } else {
            0
        }
    }

    public fun claim(vault: &mut FounderVault, founder: address): u64 {
        let amount = claimable(vault, founder);
        assert!(amount > 0, E_NOTHING_TO_CLAIM);
        *table::borrow_mut(&mut vault.last_claimed_index, founder) = vault.cumulative_index;
        amount
    }
}
