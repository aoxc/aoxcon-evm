// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcAutoRepair
 * @author AOXCAN Infrastructure Division
 * @notice The Autonomous Immune System of the AOXCAN Ecosystem.
 * @dev Implementation of Rule 12 (Self-Healing). Handles circuit-breaking and logic patching.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INTERNAL
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";
import {IAoxcAutoRepair} from "aoxc-interfaces/IAoxcAutoRepair.sol";

contract AoxcAutoRepair is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IAoxcAutoRepair
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public nexus;
    address public aiNode;
    address public auditVoice;

    /// @custom:security Target -> Selector -> IsQuarantined
    mapping(address => mapping(bytes4 => bool)) private _quarantineRegistry;
    mapping(uint256 => bool) public anomalyLedger;
    mapping(bytes4 => bool) public isImmune;

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeAutoRepairV2(address _admin, address _nexus, address _aiNode, address _auditVoice)
        external
        initializer
    {
        if (_admin == address(0) || _nexus == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();
        // __UUPSUpgradeable_init() is removed in OpenZeppelin v5+

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AoxcConstants.GUARDIAN_ROLE, _admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, _nexus);

        nexus = _nexus;
        aiNode = _aiNode;
        auditVoice = _auditVoice;

        isImmune[this.triggerEmergencyQuarantine.selector] = true;
        isImmune[this.liftQuarantine.selector] = true;
        isImmune[this.executePatch.selector] = true;
    }

    /*//////////////////////////////////////////////////////////////
                        SOVEREIGN REPAIR LOGIC
    //////////////////////////////////////////////////////////////*/

    function triggerEmergencyQuarantine(bytes4 selector, address target) external override nonReentrant {
        if (msg.sender != aiNode && !hasRole(AoxcConstants.GUARDIAN_ROLE, msg.sender)) {
            revert AoxcErrors.Aoxc_Neural_IdentityForgery();
        }

        if (isImmune[selector]) revert AoxcErrors.Aoxc_CustomRevert("REPAIR: SELECTOR_IMMUNE");
        if (target == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        _quarantineRegistry[target][selector] = true;

        emit AoxcEvents.SystemRepairInitiated(keccak256(abi.encodePacked(selector, target)), target);
    }

    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        bytes calldata aiAuthProof
    ) external override nonReentrant onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        if (anomalyLedger[anomalyId]) {
            revert AoxcErrors.Aoxc_CustomRevert("REPAIR: DUPLICATE_ID");
        }

        bytes32 digest = keccak256(abi.encode(anomalyId, selector, target, patchLogic, block.chainid, address(this)))
            .toEthSignedMessageHash();

        if (digest.recover(aiAuthProof) != aiNode) revert AoxcErrors.Aoxc_Neural_IdentityForgery();

        _quarantineRegistry[target][selector] = false;
        anomalyLedger[anomalyId] = true;

        emit AoxcEvents.PatchExecuted(selector, target, patchLogic);
    }

    function liftQuarantine(bytes4 selector, address target) external override {
        if (msg.sender != auditVoice && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert AoxcErrors.Aoxc_CustomRevert("REPAIR: UNAUTHORIZED");
        }

        _quarantineRegistry[target][selector] = false;
        emit AoxcEvents.GlobalLockStateChanged(false, 0);
    }

    function isOperational(bytes4 selector) external view override returns (bool) {
        return !_quarantineRegistry[msg.sender][selector];
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADE CONTROL
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation)
        internal
        view
        override
        onlyRole(AoxcConstants.GOVERNANCE_ROLE)
    {
        if (newImplementation == address(0)) {
            revert AoxcErrors.Aoxc_InvalidAddress();
        }
    }

    // Reserved storage slots for future upgrades (Rule 12 compliant)
    uint256[50] private __gap;
}
