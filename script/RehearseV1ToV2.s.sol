// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "aoxc-v1/AOXC.sol";
import "aoxc-v2/core/AoxcCore.sol";

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
        bytes32 integrityHash = vm.envBytes32("MIGRATION_INTEGRITY_HASH");

        vm.startBroadcast(deployerPk);

        AOXC v1Impl = new AOXC();
        AOXC v1 = AOXC(address(new ERC1967Proxy(address(v1Impl), abi.encodeWithSelector(AOXC.initialize.selector, governor))));

        AoxcCore v2Impl = new AoxcCore();
        AoxcCore v2 = AoxcCore(
            address(
                new ERC1967Proxy(
                    address(v2Impl),
                    abi.encodeWithSelector(
                        AoxcCore.initializeV2.selector,
                        address(v1),
                        nexus,
                        sentinel,
                        address(0),
                        governor,
                        integrityHash
                    )
                )
            )
        );

        vm.stopBroadcast();

        console2.log("[REHEARSAL] v1 proxy:", address(v1));
        console2.log("[REHEARSAL] v2 proxy:", address(v2));
    }
}
