// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";
import {IAoxcAutoRepair} from "aoxc-interfaces/IAoxcAutoRepair.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";



contract AoxcAutoRepair is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IAoxcAutoRepair
{
    address public core; 
    address public nexus;
    address public aiNode;
    address public auditVoice;

    mapping(address => mapping(bytes4 => bool)) private _quarantineRegistry;
    mapping(uint256 => bool) public anomalyLedger;
    mapping(bytes4 => bool) public isImmune;

    constructor() { _disableInitializers(); }

    function initializeAutoRepairV2(
        address _admin, address _core, address _nexus, address _aiNode, address _auditVoice
    ) external initializer {
        if (_admin == address(0) || _core == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AoxcConstants.GUARDIAN_ROLE, _admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, _nexus);

        core = _core;
        nexus = _nexus;
        aiNode = _aiNode;
        auditVoice = _auditVoice;

        isImmune[this.triggerEmergencyQuarantine.selector] = true;
        isImmune[this.liftQuarantine.selector] = true;
        isImmune[this.executePatch.selector] = true;
    }

    function triggerEmergencyQuarantine(
        bytes4 selector, address target, IAoxcCore.NeuralPacket calldata packet
    ) external override nonReentrant {
        if (!IAoxcCore(core).executeNeuralAction(packet)) revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);
        if (isImmune[selector]) revert AoxcErrors.Aoxc_CustomRevert("REPAIR: IMMUNE");
        
        _quarantineRegistry[target][selector] = true;
        emit SystemQuarantined(selector, target, 0);
    }

    /**
     * @dev FIX: Parametre sayısı IAoxcAutoRepair arayüzü ile (5 parametre) eşitlendi.
     */
    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        IAoxcCore.NeuralPacket calldata packet
    ) external override nonReentrant onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        if (!IAoxcCore(core).executeNeuralAction(packet)) revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);
        if (anomalyLedger[anomalyId]) revert AoxcErrors.Aoxc_CustomRevert("REPAIR: DUPLICATE_ID");

        anomalyLedger[anomalyId] = true;
        emit NeuralPatchApplied(anomalyId, patchLogic, packet.riskScore);
    }

    function liftQuarantine(
        bytes4 selector, address target, IAoxcCore.NeuralPacket calldata packet
    ) external override nonReentrant {
        if (!IAoxcCore(core).executeNeuralAction(packet)) revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && msg.sender != auditVoice) revert AoxcErrors.Aoxc_CustomRevert("REPAIR: UNAUTHORIZED");

        _quarantineRegistry[target][selector] = false;
        emit AoxcEvents.GlobalLockStateChanged(false, 0, block.timestamp);
    }

    function isOperational(bytes4 selector) external view override returns (bool) {
        return !_quarantineRegistry[msg.sender][selector];
    }

    function getRepairStatus() external view override returns (bool inRepairMode, uint256 expiry) {
        return (false, block.timestamp + 1 hours); 
    }

    function validatePatch(uint256 anomalyId) external view override returns (bool isVerified) {
        return anomalyLedger[anomalyId];
    }

    function _authorizeUpgrade(address) internal view override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {}
}
