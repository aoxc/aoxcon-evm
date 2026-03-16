// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AoxcCore} from "aoxc-v2/core/AoxcCore.sol";
import {AoxcSentinel} from "aoxc-v2/access/AoxcSentinel.sol";
import {AoxcVault} from "aoxc-v2/finance/AoxcVault.sol";

/**
 * @title QuantumLeap - AOXC V2 Upgrade & Deployment Script
 * @author AOXC Engineering
 * @notice Deploys AOXC V2 Core and Sentinel using the ERC1967 Proxy pattern.
 * * AUDIT & SECURITY COMPLIANCE:
 * 1. ENVIROMENTAL ISOLATION: Uses vm.envOr to separate Test (Anvil) from Production.
 * 2. PROXY PATTERN: Implements ERC1967 for UUPS/Transparent upgradeability.
 * 3. INITIALIZATION: Ensures V1 legacy connection is established during atomic deployment.
 */
contract QuantumLeap is Script {
    
    // --- Public Test Constants (Anvil Defaults) ---
    address constant ANVIL_V1_AOXC = 0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82;
    uint256 constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        // --- 1. Setup & Authentication ---
        // Fetch keys from .env for production, or fallback to Anvil for local dev.
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", ANVIL_KEY);
        address admin = vm.addr(deployerKey);
        address v1Address = vm.envOr("V1_ADDRESS", ANVIL_V1_AOXC);

        console.log("Starting QuantumLeap (V2 Upgrade) Sequence...");
        console.log("Network Chain ID:", block.chainid);
        console.log("Admin/Deployer  :", admin);

        vm.startBroadcast(deployerKey);

        // --- 2. V2 Core Infrastructure (Implementation + Proxy) ---
        // Deployment of the logic contract (Implementation)
        AoxcCore coreImpl = new AoxcCore();
        
        // Deployment of the Proxy pointing to the Logic contract
        // The empty string "" represents no immediate data call; we initialize separately.
        AoxcCore core = AoxcCore(address(new ERC1967Proxy(address(coreImpl), "")));
        
        // --- 3. Sentinel AI Monitoring (Implementation + Proxy) ---
        AoxcSentinel sentinelImpl = new AoxcSentinel();
        AoxcSentinel sentinel = AoxcSentinel(address(new ERC1967Proxy(address(sentinelImpl), "")));

        // --- 4. System Initialization (The "Quantum Leap") ---
        /**
         * @dev We initialize V2 to link with V1 Legacy and setup roles.
         * This step is critical; in production, 'admin' should eventually be a Multi-Sig.
         */
        core.initializeV2(
            v1Address,                     // Legacy V1 Connection
            admin,                         // Governance Hub
            address(sentinel),             // Sentinel AI Link
            admin,                         // Repair Engine
            admin,                         // Global Admin
            keccak256("AOXC_V2_PROD_READY") // Versioning Salt
        );

        // --- 5. Final Logging ---
        console.log("----------------------------------------------");
        console.log("V2 Core (Proxy)  :", address(core));
        console.log("V2 Core (Impl)   :", address(coreImpl));
        console.log("Sentinel (Proxy) :", address(sentinel));
        console.log("V1 Legacy Linked :", v1Address);
        console.log("----------------------------------------------");
        console.log("V2 Deployment Status: SUCCESSFUL");

        vm.stopBroadcast();
    }
}
