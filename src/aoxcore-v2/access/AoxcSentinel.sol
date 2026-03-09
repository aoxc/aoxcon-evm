// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcSentinel
 * @author AOXCAN Security Division
 * @notice Constitutional Gatekeeper of the AOXC Ecosystem.
 * @dev High-integrity implementation using EIP-712 structured signatures.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// AOXC INTERNAL
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";

interface IAutoRepair {
    function triggerEmergencyQuarantine(
        bytes4 selector, 
        address target, 
        IAoxcCore.NeuralPacket calldata packet
    ) external;
}

contract AoxcSentinel is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    EIP712Upgradeable
{
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                AUDIT-READY NAMESPACED STORAGE (ERC-7201)
    //////////////////////////////////////////////////////////////*/

    struct SentinelStorage {
        address aiNodeAddress;
        address coreAddress;
        address repairEngine;
        uint256 riskThreshold;
        uint256 signalWindow;
        bool bastionSealed;
        mapping(address => uint256) operationalNonces;
    }

    bytes32 private constant SENTINEL_STORAGE_LOCATION =
        0x9331003666f7d025170d9e9e6f2bc8b671d1796c739a8976136f78816f1f6c00;

    function _getStore() internal pure returns (SentinelStorage storage $) {
        assembly { $.slot := SENTINEL_STORAGE_LOCATION }
    }

    bytes32 private constant NEURAL_PACKET_TYPEHASH =
        keccak256("NeuralPacket(address origin,address target,uint256 value,uint256 nonce,uint48 deadline,uint16 reasonCode,uint8 riskScore,bool autoRepairMode,bytes32 protocolHash)");

    bytes32 private constant INTERCEPTION_TYPEHASH =
        keccak256("Interception(uint8 riskScore,uint256 nonce,address target,bytes4 selector)");

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR & INIT
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeV2(address admin, address aiNode, address core, address repair) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __EIP712_init("AoxcSentinel", "2.5");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.SENTINEL_ROLE, admin);

        SentinelStorage storage $ = _getStore();
        if (aiNode == address(0) || core == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        $.aiNodeAddress = aiNode;
        $.coreAddress = core;
        $.repairEngine = repair;
        $.riskThreshold = AoxcConstants.NEURAL_RISK_CRITICAL;
        $.signalWindow = 50;
    }

    /*//////////////////////////////////////////////////////////////
                NEURAL HANDSHAKE VERIFIER (VIEW ONLY)
    //////////////////////////////////////////////////////////////*/

    function verifyHandshake(
        IAoxcCore.NeuralPacket calldata packet
    ) external view returns (bool) {
        SentinelStorage storage $ = _getStore();

        if ($.bastionSealed || paused()) return false;
        if (block.timestamp > packet.deadline) return false;

        bytes32 structHash = keccak256(
            abi.encode(
                NEURAL_PACKET_TYPEHASH,
                packet.origin,
                packet.target,
                packet.value,
                packet.nonce,
                packet.deadline,
                packet.reasonCode,
                packet.riskScore,
                packet.autoRepairMode,
                packet.protocolHash
            )
        );

        address recovered = _hashTypedDataV4(structHash).recover(packet.neuralSignature);
        return (recovered == $.aiNodeAddress && packet.riskScore <= $.riskThreshold);
    }

    /*//////////////////////////////////////////////////////////////
                        SURGICAL INTERCEPTION
    //////////////////////////////////////////////////////////////*/

    function processInterception(
        uint8 riskScore,
        uint256 nonce,
        address target,
        bytes4 selector,
        bytes calldata signature
    ) external nonReentrant {
        SentinelStorage storage $ = _getStore();

        bytes32 structHash = keccak256(abi.encode(INTERCEPTION_TYPEHASH, riskScore, nonce, target, selector));
        if (_hashTypedDataV4(structHash).recover(signature) != $.aiNodeAddress) {
            revert AoxcErrors.Aoxc_Neural_IdentityForgery();
        }

        if (nonce <= $.operationalNonces[target]) {
            revert AoxcErrors.Aoxc_Neural_InvalidNonce(nonce, $.operationalNonces[target]);
        }
        $.operationalNonces[target] = nonce;

        if (riskScore >= $.riskThreshold) {
            _executeIsolation($, target, selector, riskScore);
        }

        emit AoxcEvents.NeuralValidationSucceeded(structHash, msg.sender, AoxcConstants.REASON_DEFENSE_TRIGGER, riskScore);
    }

    function _executeIsolation(SentinelStorage storage $, address target, bytes4 selector, uint8 riskScore) internal {
        try IAoxcCore($.coreAddress).triggerEmergencyRepair(selector, target, "SENTINEL_INTERCEPTION") {} 
        catch {
             try IAoxcCore($.coreAddress).setRestrictionStatus(target, true, "SENTINEL_VETO") {} catch {}
        }

        if ($.repairEngine != address(0)) {
            IAoxcCore.NeuralPacket memory packet;
            packet.riskScore = riskScore;
            packet.reasonCode = uint16(AoxcConstants.REASON_DEFENSE_TRIGGER);

            try IAutoRepair($.repairEngine).triggerEmergencyQuarantine(selector, target, packet) {
                emit AoxcEvents.SystemRepairInitiated(keccak256("SENTINEL_REPAIR"), target);
            } catch {
                _triggerRule10Emergency($);
            }
        }
    }

    function _triggerRule10Emergency(SentinelStorage storage $) internal {
        $.bastionSealed = true;
        _pause();
        emit AoxcEvents.GlobalLockStateChanged(true, 0, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN & AUDIT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns EIP-712 Domain Separator for testing.
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function updateRiskThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newThreshold > 255) revert AoxcErrors.Aoxc_Neural_RiskTooHigh(uint8(newThreshold), 255);
        _getStore().riskThreshold = newThreshold;
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    function isBastionSealed() external view returns (bool) { return _getStore().bastionSealed; }
    function getOperationalNonce(address target) external view returns (uint256) { return _getStore().operationalNonces[target]; }
}
