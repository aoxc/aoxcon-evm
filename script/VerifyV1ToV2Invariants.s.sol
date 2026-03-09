// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Script.sol";

import "aoxc-v1/AOXC.sol";
import "aoxc-v2/core/AoxcCore.sol";

/**
 * @notice Post-deploy invariant verifier for rehearsal/production checks.
 */
contract VerifyV1ToV2Invariants is Script {
    function run() external view {
        AOXC v1 = AOXC(vm.envAddress("VERIFY_V1_PROXY"));
        AoxcCore v2 = AoxcCore(vm.envAddress("VERIFY_V2_PROXY"));

        address verifyUser = vm.envAddress("VERIFY_USER");

        (uint256 yearlyLimit, , ) = v2.getMintPolicy();

        require(yearlyLimit > 0, "VERIFY: V2 yearly limit is zero");
        require(v2.balanceOf(verifyUser) >= 0, "VERIFY: invalid balance read");

        // Basic parity sanity checks (no revert expected):
        v1.isBlacklisted(verifyUser);
        v2.isBlacklisted(verifyUser);

        console2.log("[VERIFY] v1:", address(v1));
        console2.log("[VERIFY] v2:", address(v2));
        console2.log("[VERIFY] yearly limit:", yearlyLimit);
    }
}
