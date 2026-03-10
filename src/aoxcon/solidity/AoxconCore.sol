// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import {AoxconHonor} from "./AoxconHonor.sol";
import {AoxconXasToken} from "./AoxconXasToken.sol";
import {AoxconBridge} from "./AoxconBridge.sol";
import {AoxconVerifierRegistry} from "./AoxconVerifierRegistry.sol";

/// @title AoxconCore
/// @notice
/// Modest profile:
/// - Verified Integrity
/// - V1 Legacy
contract AoxconCore is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    AoxconHonor public honor;
    AoxconXasToken public xas;
    AoxconBridge public bridge;
    AoxconVerifierRegistry public verifierRegistry;

    bytes32 public systemConfigHash;

    event ModulesBound(address indexed honor, address indexed xas, address indexed bridge, address registry);
    event ConfigHashUpdated(bytes32 oldHash, bytes32 newHash);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, bytes32 initialConfigHash) external initializer {
        require(admin != address(0), "CORE: ZERO_ADMIN");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);

        systemConfigHash = initialConfigHash;
    }

    function bindModules(address honor_, address xas_, address bridge_, address registry_) external onlyRole(GOVERNOR_ROLE) {
        require(honor_ != address(0), "CORE: ZERO_HONOR");
        require(xas_ != address(0), "CORE: ZERO_XAS");
        require(bridge_ != address(0), "CORE: ZERO_BRIDGE");
        require(registry_ != address(0), "CORE: ZERO_REGISTRY");

        honor = AoxconHonor(honor_);
        xas = AoxconXasToken(xas_);
        bridge = AoxconBridge(bridge_);
        verifierRegistry = AoxconVerifierRegistry(registry_);

        emit ModulesBound(honor_, xas_, bridge_, registry_);
    }

    function wireBridgeToXas() external onlyRole(GOVERNOR_ROLE) {
        require(address(bridge) != address(0) && address(xas) != address(0), "CORE: NOT_BOUND");
        xas.rotateBridge(address(bridge));
    }

    function configureVerifier(uint256 chainId, address verifier, bool active, string calldata label)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(address(verifierRegistry) != address(0), "CORE: NOT_BOUND");
        verifierRegistry.configureVerifier(chainId, verifier, active, label);
    }

    function setSystemConfigHash(bytes32 nextHash) external onlyRole(GOVERNOR_ROLE) {
        bytes32 oldHash = systemConfigHash;
        systemConfigHash = nextHash;
        emit ConfigHashUpdated(oldHash, nextHash);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
