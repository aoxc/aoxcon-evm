// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";

import {AOXC} from "aoxc-v1/AOXC.sol";
import {AoxcCore} from "aoxc-v2/core/AoxcCore.sol";
import {AoxcConstants} from "aoxc-v2/libraries/AoxcConstants.sol";

/**
 * @notice Post-deploy invariant verifier for rehearsal/production checks.
 */
contract VerifyV1ToV2Invariants is Script {
    function run() external view {
        AOXC v1 = AOXC(vm.envAddress("VERIFY_V1_PROXY"));
        address v2Proxy = vm.envOr("VERIFY_V2_PROXY", address(v1));
        AoxcCore v2 = AoxcCore(v2Proxy);

        address verifyUser = vm.envAddress("VERIFY_USER");
        address expectedAdmin = vm.envAddress("VERIFY_EXPECTED_ADMIN");
        address expectedNexus = vm.envAddress("VERIFY_EXPECTED_NEXUS");
        address expectedSentinel = vm.envAddress("VERIFY_EXPECTED_SENTINEL");

        (uint256 yearlyLimit, , ) = v2.getMintPolicy();
        uint256 expectedYearlyLimit = (v1.totalSupply() * 600) / AoxcConstants.BPS_DENOMINATOR;

        require(yearlyLimit > 0, "VERIFY: V2 yearly limit is zero");
        require(yearlyLimit == expectedYearlyLimit, "VERIFY: mint policy parity mismatch");

        require(v2.hasRole(0x00, expectedAdmin), "VERIFY: missing DEFAULT_ADMIN_ROLE");
        require(v2.hasRole(AoxcConstants.GOVERNANCE_ROLE, expectedNexus), "VERIFY: missing GOVERNANCE_ROLE");
        require(v2.hasRole(AoxcConstants.SENTINEL_ROLE, expectedSentinel), "VERIFY: missing SENTINEL_ROLE");

        v2.balanceOf(verifyUser);

        // Basic parity sanity checks (no revert expected):
        v1.isBlacklisted(verifyUser);
        v2.isBlacklisted(verifyUser);

        console2.log("[VERIFY] v1:", address(v1));
        console2.log("[VERIFY] v2:", address(v2));
        console2.log("[VERIFY] yearly limit:", yearlyLimit);
    }
}
