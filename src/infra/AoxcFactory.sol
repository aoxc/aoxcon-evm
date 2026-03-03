// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// AOXC Core Imports
import "aoxc-core/AoxcRegistry.sol";
import "aoxc-finance/AoxcVault.sol";
import "aoxc-core/AoxcNexus.sol";
import "aoxc-finance/AoxcCpex.sol";
import "aoxc-libraries/AoxcConstants.sol";
import "aoxc-libraries/AoxcErrors.sol";

/**
 * @title AoxcFactory
 * @author AOXCAN Core
 * @notice Automated deployment engine for V2.2 Neural Ecosystem.
 * @dev High-Priority: Implements Rule 10 (Sovereign Upgrade) & Rule 12 (Self-Healing).
 */
contract AoxcFactory is Ownable {
    // V1 DNA - IMMUTABLE ROOTS
    address public constant AOXC_TOKEN_V1 = 0xeB9580c3946BB47d73AAE1d4f7A94148B554b2F4;
    address public constant MAIN_ADMIN_V1 = 0x97Bdd1fD1CAF756e00eFD42eBa9406821465B365;
    address public constant MULTISIG_V1 = 0x20c0DD8B6559912acfAC2ce061B8d5b19Db8CA84;

    struct DeploymentSuite {
        address registry;
        address vault;
        address nexus;
        address cpex;
    }

    event EcosystemInitialized(DeploymentSuite suite);
    event SovereigntyTransferred(address indexed newOwner);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Deploys the ecosystem and enforces the 10 Neural Laws.
     * @dev RULE 10: Logic upgrades are strictly via UUPS and governed by Nexus.
     */
    function deployV2Ecosystem(address aiSentinel) external onlyOwner returns (DeploymentSuite memory suite) {
        if (aiSentinel == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        // 1. Deploy Logic Implementations (Gas Efficient)
        address regImpl = address(new AoxcRegistry());
        address vltImpl = address(new AoxcVault());
        address nexImpl = address(new AoxcNexus());
        address cpxImpl = address(new AoxcCpex());

        // 2. NEXUS (Governance & Veto)
        bytes memory nexusInit =
            abi.encodeWithSelector(AoxcNexus.initializeNexusV2.selector, MULTISIG_V1, aiSentinel, AOXC_TOKEN_V1);
        suite.nexus = address(new ERC1967Proxy(nexImpl, nexusInit));

        // 3. REGISTRY (Identity & Reputation)
        bytes memory regInit = abi.encodeWithSelector(AoxcRegistry.initializeRegistryV2.selector, MAIN_ADMIN_V1);
        suite.registry = address(new ERC1967Proxy(regImpl, regInit));

        // 4. VAULT (Treasury & Lockdown)
        bytes memory vaultInit = abi.encodeWithSelector(
            AoxcVault.initializeVaultV2.selector,
            suite.nexus, // Nexus is the Governor
            AOXC_TOKEN_V1
        );
        suite.vault = address(new ERC1967Proxy(vltImpl, vaultInit));

        // 5. CPEX (Staking & Yield Engine)
        bytes memory cpexInit = abi.encodeWithSelector(
            AoxcCpex.initializeCpexV2.selector, suite.nexus, aiSentinel, AOXC_TOKEN_V1, suite.vault
        );
        suite.cpex = address(new ERC1967Proxy(cpxImpl, cpexInit));

        // --- NEURAL BINDING (Rule 12: Atomic Interconnectivity) ---

        // Bind Sentinel and Governance to Registry for Reputation updates
        AoxcRegistry(suite.registry).grantRole(AoxcConstants.GOVERNANCE_ROLE, suite.nexus);
        AoxcRegistry(suite.registry).grantRole(AoxcConstants.SENTINEL_ROLE, aiSentinel);

        // Bind Sentinel to Vault for Rule 12 Emergency Lockdown
        AoxcVault(suite.vault).grantRole(AoxcConstants.SENTINEL_ROLE, aiSentinel);

        // FINAL SOVEREIGNTY: Transfer Factory control to MultiSig
        // This ensures the Factory cannot be used to manipulate proxies later.
        _transferOwnership(MULTISIG_V1);

        emit EcosystemInitialized(suite);
        emit SovereigntyTransferred(MULTISIG_V1);
    }
}
