// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {AoxconHonor} from "./AoxconHonor.sol";
import {AoxconXasToken} from "./AoxconXasToken.sol";
import {AoxconBridge} from "./AoxconBridge.sol";
import {AoxconVerifierRegistry} from "./AoxconVerifierRegistry.sol";

/// @title AoxconCore
/// @notice
/// Modest profile:
/// - Verified Integrity
/// - V1 Legacy
/// @dev Honor, XAS, Bridge ve Registry adreslerini bir araya getirir.
contract AoxconCore is AccessControl {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    AoxconHonor public honor;
    AoxconXasToken public xas;
    AoxconBridge public bridge;
    AoxconVerifierRegistry public verifierRegistry;

    event ModulesBound(address honor, address xas, address bridge, address registry);

    constructor(address admin) {
        require(admin != address(0), "CORE: ZERO_ADMIN");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
    }

    function bindModules(address honor_, address xas_, address bridge_, address registry_)
        external
        onlyRole(GOVERNOR_ROLE)
    {
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

    function setBridgeOnXas() external onlyRole(GOVERNOR_ROLE) {
        require(address(xas) != address(0) && address(bridge) != address(0), "CORE: NOT_BOUND");
        xas.setBridge(address(bridge));
    }

    function setVerifier(uint256 chainId, address verifier) external onlyRole(GOVERNOR_ROLE) {
        require(address(verifierRegistry) != address(0), "CORE: NOT_BOUND");
        verifierRegistry.setVerifier(chainId, verifier);
    }
}
