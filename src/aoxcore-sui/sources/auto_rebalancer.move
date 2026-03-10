module aoxcore::auto_rebalancer {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    const E_INVALID_BPS: u64 = 4001;

    /// System-level auto balance policy:
    /// - founder_share_bps: legacy honor holders allocation
    /// - xas_share_bps: AOXC-XAS ecosystem allocation
    /// - reserve_share_bps: protocol stability reserve
    public struct RebalancePolicy has key {
        id: UID,
        founder_share_bps: u64,
        xas_share_bps: u64,
        reserve_share_bps: u64,
    }

    public struct RebalancerAdminCap has key {
        id: UID,
    }

    public fun init(ctx: &mut TxContext): (RebalancePolicy, RebalancerAdminCap) {
        (
            RebalancePolicy {
                id: object::new(ctx),
                founder_share_bps: 3000,
                xas_share_bps: 5000,
                reserve_share_bps: 2000,
            },
            RebalancerAdminCap { id: object::new(ctx) }
        )
    }

    public fun set_policy(
        _cap: &RebalancerAdminCap,
        policy: &mut RebalancePolicy,
        founder_share_bps: u64,
        xas_share_bps: u64,
        reserve_share_bps: u64
    ) {
        assert!(founder_share_bps + xas_share_bps + reserve_share_bps == 10000, E_INVALID_BPS);
        policy.founder_share_bps = founder_share_bps;
        policy.xas_share_bps = xas_share_bps;
        policy.reserve_share_bps = reserve_share_bps;
    }

    /// Returns amounts split by policy for a given input `income`.
    public fun split_income(policy: &RebalancePolicy, income: u64): (u64, u64, u64) {
        let founder = (income * policy.founder_share_bps) / 10000;
        let xas = (income * policy.xas_share_bps) / 10000;
        let reserve = income - founder - xas;
        (founder, xas, reserve)
    }
}
