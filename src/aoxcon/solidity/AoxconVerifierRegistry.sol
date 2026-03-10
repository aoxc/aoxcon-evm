// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IAoxconZkVerifier {
    function verify(bytes calldata proof, bytes calldata context) external view returns (bool);
}

contract AoxconVerifierRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant VERIFIER_ADMIN_ROLE = keccak256("VERIFIER_ADMIN_ROLE");

    struct VerifierConfig {
        address verifier;
        bool active;
        string label;
    }

    mapping(uint256 chainId => VerifierConfig config) private _verifiers;

    event VerifierConfigured(uint256 indexed chainId, address indexed verifier, bool active, string label);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        require(admin != address(0), "REGISTRY: ZERO_ADMIN");

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(VERIFIER_ADMIN_ROLE, admin);
    }

    function configureVerifier(uint256 chainId, address verifier, bool active, string calldata label)
        external
        onlyRole(VERIFIER_ADMIN_ROLE)
    {
        require(chainId != 0, "REGISTRY: ZERO_CHAIN");
        require(verifier != address(0), "REGISTRY: ZERO_VERIFIER");

        _verifiers[chainId] = VerifierConfig({verifier: verifier, active: active, label: label});
        emit VerifierConfigured(chainId, verifier, active, label);
    }

    function getVerifier(uint256 chainId) external view returns (VerifierConfig memory) {
        return _verifiers[chainId];
    }

    function resolveActiveVerifier(uint256 chainId) external view returns (address) {
        VerifierConfig memory cfg = _verifiers[chainId];
        if (!cfg.active) return address(0);
        return cfg.verifier;
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
