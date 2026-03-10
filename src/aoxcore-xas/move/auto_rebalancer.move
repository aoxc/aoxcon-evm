module aoxcore_xas::auto_rebalancer {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};

    const E_INVALID_TOTAL_BPS: u64 = 5201;

    public struct RebalancePolicy has key {
        id: UID,
        founder_bps: u64,
        xas_bps: u64,
        reserve_bps: u64,
    }

    public struct RebalanceAdminCap has key {
        id: UID,
    }

    public fun init(ctx: &mut TxContext): (RebalancePolicy, RebalanceAdminCap) {
        (
            RebalancePolicy {
                id: object::new(ctx),
                founder_bps: 3000,
                xas_bps: 5000,
                reserve_bps: 2000,
            },
            RebalanceAdminCap { id: object::new(ctx) },
        )
    }

    public fun set_policy(
        _cap: &RebalanceAdminCap,
        policy: &mut RebalancePolicy,
        founder_bps: u64,
        xas_bps: u64,
        reserve_bps: u64,
    ) {
        assert!(founder_bps + xas_bps + reserve_bps == 10000, E_INVALID_TOTAL_BPS);
        policy.founder_bps = founder_bps;
        policy.xas_bps = xas_bps;
        policy.reserve_bps = reserve_bps;
    }

    public fun split(policy: &RebalancePolicy, income: u64): (u64, u64, u64) {
        let founder_amount = (income * policy.founder_bps) / 10000;
        let xas_amount = (income * policy.xas_bps) / 10000;
        let reserve_amount = income - founder_amount - xas_amount;
        (founder_amount, xas_amount, reserve_amount)
    }
}
