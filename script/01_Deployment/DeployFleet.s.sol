// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// --- Yollar Düzenlendi (Remapping Uyumlu) ---
import {AoxcCore} from "aoxc-core/AoxcCore.sol";
import {AoxcSentinel} from "aoxc/access/AoxcSentinel.sol"; // Tree çıktına göre access altında
import {AoxcRegistry} from "aoxc-core/AoxcRegistry.sol";

contract DeployFleet is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerKey);

        console2.log(unicode"\n-------------------------------------------");
        console2.log(unicode"🏛️  AOXC GENESIS V2.0.0 | SOVEREIGN FLEET");
        console2.log(unicode"-------------------------------------------");
        console2.log(unicode"Deployer Address: ", admin);
        console2.log(unicode"Target Network:   X LAYER");

        vm.startBroadcast(deployerKey);

        // 1. Deploy Registry (Master Orchestrator)
        console2.log(unicode"\n[1/3] Launching Registry (The Orchestrator)...");
        AoxcRegistry registryImpl = new AoxcRegistry();
        ERC1967Proxy registryProxy =
            new ERC1967Proxy(address(registryImpl), abi.encodeWithSelector(AoxcRegistry.initialize.selector, admin));
        console2.log(unicode">>> Registry Proxy deployed at:", address(registryProxy));

        // 2. Deploy Sentinel (Neural Guard)
        console2.log(unicode"\n[2/3] Activating Sentinel (Neural Guard)...");
        AoxcSentinel sentinelImpl = new AoxcSentinel();
        ERC1967Proxy sentinelProxy = new ERC1967Proxy(
            address(sentinelImpl),
            abi.encodeWithSelector(AoxcSentinel.initializeV2.selector, admin, admin, address(0), address(0))
        );
        console2.log(unicode">>> Sentinel Proxy deployed at:", address(sentinelProxy));

        // 3. Deploy Core (The Heart)
        console2.log(unicode"\n[3/3] Pulsing Core (The Sovereign Heart)...");
        AoxcCore coreImpl = new AoxcCore();
        ERC1967Proxy coreProxy = new ERC1967Proxy(
            address(coreImpl),
            abi.encodeWithSelector(
                AoxcCore.initializeV2.selector,
                address(0),
                admin,
                address(sentinelProxy),
                address(0),
                admin,
                keccak256("AOXC_V2")
            )
        );
        console2.log(unicode">>> Core Proxy deployed at:", address(coreProxy));

        vm.stopBroadcast();

        console2.log(unicode"\n-------------------------------------------");
        console2.log(unicode"✅ FLEET DEPLOYMENT SEQUENCE COMPLETE");
        console2.log(unicode"AOXC Security Division Seal: [VALIDATED]");
        console2.log(unicode"-------------------------------------------\n");
    }
}
