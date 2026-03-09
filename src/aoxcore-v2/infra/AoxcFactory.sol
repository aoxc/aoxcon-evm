// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// AOXC Core Imports - Path sync check required for your project structure
import "aoxc-core/AoxcRegistry.sol";
import "aoxc-finance/AoxcVault.sol";
import "aoxc-core/AoxcNexus.sol";
import "aoxc-finance/AoxcCpex.sol";
import "aoxc-libraries/AoxcConstants.sol";
import "aoxc-libraries/AoxcErrors.sol";

/**
 * @title AoxcFactory
 * @author AOXCAN Core
 * @notice V2.2 Neural Ekosistemi için otomatik dağıtım motoru.
 * @dev RULE 10 (Upgradeability) ve RULE 12 (Self-Healing) protokollerini uygular.
 */
contract AoxcFactory is Ownable {
    // V1 DNA - IMMUTABLE ROOTS (X-Layer & Mainnet Sync)
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
     * @notice Ekosistemi dağıtır ve 10 Neural Kanununu akıllı kontrat seviyesinde mühürler.
     * @param aiSentinel AI Sentinel (Karujan) guardian adresi.
     */
    function deployV2Ecosystem(address aiSentinel) external onlyOwner returns (DeploymentSuite memory suite) {
        if (aiSentinel == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        // 1. Deploy Logic Implementations (Gas Efficient - Bir kez dağıtılır)
        address regImpl = address(new AoxcRegistry());
        address vltImpl = address(new AoxcVault());
        address nexImpl = address(new AoxcNexus());
        address cpxImpl = address(new AoxcCpex());

        // 2. NEXUS (Governance & Neural Veto)
        bytes memory nexusInit = abi.encodeWithSelector(
            AoxcNexus.initializeNexusV2.selector, 
            MULTISIG_V1, 
            aiSentinel, 
            AOXC_TOKEN_V1
        );
        suite.nexus = address(new ERC1967Proxy(nexImpl, nexusInit));

        // 3. REGISTRY (Identity & Reputation) 
        bytes memory regInit = abi.encodeWithSelector(
            AoxcRegistry.initializeRegistryV2.selector, 
            MAIN_ADMIN_V1
        );
        suite.registry = address(new ERC1967Proxy(regImpl, regInit));

        // 4. VAULT (Treasury & Sovereign Asset Management)
        bytes memory vaultInit = abi.encodeWithSelector(
            AoxcVault.initializeVaultV2.selector,
            suite.nexus, 
            AOXC_TOKEN_V1
        );
        suite.vault = address(new ERC1967Proxy(vltImpl, vaultInit));

        // 5. CPEX (Neural Yield & Staking Engine)
        bytes memory cpexInit = abi.encodeWithSelector(
            AoxcCpex.initializeCpexV2.selector, 
            suite.nexus, 
            aiSentinel, 
            AOXC_TOKEN_V1, 
            suite.vault
        );
        suite.cpex = address(new ERC1967Proxy(cpxImpl, cpexInit));

        // --- NEURAL BINDING (Sistemlerin Birbirine Bağlanması) ---
        _grantInitialRoles(suite, aiSentinel);

        // FINAL SOVEREIGNTY: Factory kontrolünü MultiSig'e devret.
        _transferOwnership(MULTISIG_V1);

        emit EcosystemInitialized(suite);
        emit SovereigntyTransferred(MULTISIG_V1);
    }

    /**
     * @dev Dahili fonksiyon: Cross-contract rollerini mühürler.
     */
    function _grantInitialRoles(DeploymentSuite memory suite, address aiSentinel) internal {
        // Registry Yetkilendirmeleri
        try AoxcRegistry(suite.registry).grantRole(AoxcConstants.GOVERNANCE_ROLE, suite.nexus) {} catch {}
        try AoxcRegistry(suite.registry).grantRole(AoxcConstants.SENTINEL_ROLE, aiSentinel) {} catch {}

        // Vault Yetkilendirmeleri
        // FIX: Error (7398) Resolved - Payable casting added for AoxcVault due to fallback function
        try AoxcVault(payable(suite.vault)).grantRole(AoxcConstants.SENTINEL_ROLE, aiSentinel) {} catch {}
    }
}
