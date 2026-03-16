// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AOXC} from "aoxc-v1/AOXC.sol";
import {AoxcCore} from "aoxc-v2/core/AoxcCore.sol";

/**
 * @notice Rehearsal-only migration bootstrap for v1 -> v2 verification.
 * @dev This is intentionally explicit and operator-friendly for auditability.
 */
contract RehearseV1ToV2 is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address governor = vm.envAddress("MIGRATION_GOVERNOR");
        address nexus = vm.envAddress("MIGRATION_NEXUS");
        address sentinel = vm.envAddress("MIGRATION_SENTINEL");
        address repair = vm.envOr("MIGRATION_REPAIR", address(0));
        address upgrader = vm.envOr("MIGRATION_UPGRADER", governor);
        bytes32 integrityHash = vm.envBytes32("MIGRATION_INTEGRITY_HASH");

        require(vm.addr(deployerPk) == governor, "REHEARSAL: DEPLOYER_NOT_GOVERNOR");

        vm.startBroadcast(deployerPk);

        AOXC v1Impl = new AOXC();
        ERC1967Proxy v1Proxy = new ERC1967Proxy(address(v1Impl), abi.encodeWithSelector(AOXC.initialize.selector, governor));
        AOXC v1 = AOXC(address(v1Proxy));

        AoxcCore v2Impl = new AoxcCore();

        // Rehearsal path: perform in-place implementation switch as production would.
        vm.prank(governor);
        v1.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(
                AoxcCore.migrateFromV1.selector,
                address(v1),
                nexus,
                sentinel,
                repair,
                upgrader,
                integrityHash
            )
        );

        AoxcCore v2 = AoxcCore(address(v1Proxy));

        vm.stopBroadcast();

        console2.log("[REHEARSAL] migrated proxy:", address(v2));
    }
}
