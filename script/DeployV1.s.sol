// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {AOXC} from "aoxc-v1/AOXC.sol";

/**
 * @title AOXC_Deployment_V1
 * @author AOXC Dev Team
 * @notice Automated deployment script for the AOXC Token.
 * * SECURITY ARCHITECTURE NOTE:
 * This script implements a dual-layer security approach:
 * 1. LOCAL DEV: Uses hardcoded Anvil/Hardhat keys for rapid local testing.
 * 2. PRODUCTION: Uses environment variables (vm.envUint) to prevent private key leakage.
 * * WARNING: Never commit real private keys to version control (GitHub).
 */
contract DeployV1 is Script {
    
    // --- Constant Test Credentials (Publicly Known Anvil Accounts) ---
    // These are safe to expose as they only hold value on local test nets.
    uint256 internal constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address internal constant ANVIL_OWNER_1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address internal constant ANVIL_OWNER_2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function run() external {
        // --- 1. Key Management ---
        // Checks if 'PRIVATE_KEY' exists in .env; if not, falls back to Anvil for local safety.
        uint256 deployerKey = vm.envOr("PRIVATE_KEY", ANVIL_DEFAULT_KEY);
        address deployerAddr = vm.addr(deployerKey);

        // --- 2. Multi-Sig / Owner Setup ---
        // In production, these should be Gnosis Safe or Ledger addresses.
        address owner1 = vm.envOr("OWNER_1", ANVIL_OWNER_1);
        address owner2 = vm.envOr("OWNER_2", ANVIL_OWNER_2);

        console.log("Starting deployment on Chain ID:", block.chainid);
        console.log("Deployer Address:", deployerAddr);

        // --- 3. Execution ---
        vm.startBroadcast(deployerKey);

        // Deploying the AOXC Logic Contract
        AOXC v1 = new AOXC();
        
        // Log the deployment for verification
        console.log("----------------------------------------------");
        console.log("AOXC V1 deployed at:", address(v1));
        console.log("Target Owner 1:", owner1);
        console.log("Target Owner 2:", owner2);
        console.log("----------------------------------------------");

        /**
         * @dev POST-DEPLOYMENT SECURITY STEPS:
         * 1. If using AccessControl, grant DEFAULT_ADMIN_ROLE to a Multi-Sig.
         * 2. Renounce roles from the deployer address to prevent centralization.
         */

        vm.stopBroadcast();
    }
}
