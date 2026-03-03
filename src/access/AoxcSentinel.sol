// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcSentinel (Neural V2.5)
 * @author AOXCAN Security Division
 * @notice Constitutional Gatekeeper of the AOXC Ecosystem.
 * @dev High-integrity implementation using EIP-712 structured signatures.
 * * AUDIT SCOPE:
 * 1. Rule 7 (Risk Threshold Enforcement)
 * 2. Rule 10 (Fail-Safe Mechanism)
 * 3. ERC-7201 (Namespaced Storage Integrity)
 * 4. Rule 4 (Anti-Replay via Operational Nonces)
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";

/**
 * @dev External interface for the Auto-Repair engine to isolate threats.
 */
interface IAutoRepair {
    function triggerEmergencyQuarantine(bytes4 selector, address target) external;
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
        address aiNodeAddress; // Trusted AI Signer
        address coreAddress; // Constitutional Core
        address repairEngine; // Autonomous Repair module
        uint256 riskThreshold; // Rule 7 critical level
        uint256 signalWindow; // Max block delay
        bool bastionSealed; // Global emergency halt (Rule 10)
        mapping(address => uint256) operationalNonces; // Cross-module replay protection
    }

    /**
     * @dev keccak256(abi.encode(uint256(keccak256("aoxc.storage.Sentinel")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant SENTINEL_STORAGE_LOCATION =
        0x9331003666f7d025170d9e9e6f2bc8b671d1796c739a8976136f78816f1f6c00;

    function _getStore() internal pure returns (SentinelStorage storage $) {
        assembly { $.slot := SENTINEL_STORAGE_LOCATION }
    }

    // EIP-712 Typehashes for deterministic verification
    bytes32 private constant NEURAL_PACKET_TYPEHASH =
        keccak256("NeuralPacket(address origin,uint256 nonce,uint8 riskScore,bytes32 protocolHash,uint256 deadline)");

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

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.SENTINEL_ROLE, admin);

        SentinelStorage storage $ = _getStore();
        if (aiNode == address(0) || core == address(0)) revert AoxcErrors.Aoxc_Unauthorized("ZERO_ADDR", msg.sender);

        $.aiNodeAddress = aiNode;
        $.coreAddress = core;
        $.repairEngine = repair;
        $.riskThreshold = AoxcConstants.NEURAL_RISK_CRITICAL;
        $.signalWindow = 50;
    }

    /*//////////////////////////////////////////////////////////////
                NEURAL HANDSHAKE VERIFIER (VIEW ONLY)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Performs a cryptographic check of the AI's Neural Handshake.
     * @dev Follows EIP-712 standard for structured data hashing.
     * @return bool True if signature is valid and risk is within bounds.
     */
    function verifyHandshake(IAoxcStorage.NeuralPacket calldata packet, bytes calldata aiSignature)
        external
        view
        returns (bool)
    {
        SentinelStorage storage $ = _getStore();

        // Rule 10: Fail-close if system is sealed or paused
        if ($.bastionSealed || paused()) return false;

        // Rule 5: Check temporal collision
        if (block.timestamp > packet.deadline) return false;

        bytes32 structHash = keccak256(
            abi.encode(
                NEURAL_PACKET_TYPEHASH,
                packet.origin,
                packet.nonce,
                packet.riskScore,
                packet.protocolHash,
                packet.deadline
            )
        );

        // Audit Check: Recover address using EIP-712 typed data hashing
        address recovered = _hashTypedDataV4(structHash).recover(aiSignature);

        // Rule 7 & Identity check
        return (recovered == $.aiNodeAddress && packet.riskScore <= $.riskThreshold);
    }

    /*//////////////////////////////////////////////////////////////
                    SURGICAL INTERCEPTION (EXECUTION)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Intercepts and isolates threats in real-time based on AI signals.
     * @dev Employs Rule 12 surgical defense and Rule 4 anti-replay.
     */
    function processInterception(
        uint8 riskScore,
        uint256 nonce,
        address target,
        bytes4 selector,
        bytes calldata signature
    ) external nonReentrant {
        SentinelStorage storage $ = _getStore();

        // 1. Integrity Check (EIP-712)
        bytes32 structHash = keccak256(abi.encode(INTERCEPTION_TYPEHASH, riskScore, nonce, target, selector));

        if (_hashTypedDataV4(structHash).recover(signature) != $.aiNodeAddress) {
            revert AoxcErrors.Aoxc_Neural_IdentityForgery();
        }

        // 2. Anti-Replay (Rule 4)
        if (nonce <= $.operationalNonces[target]) {
            revert AoxcErrors.Aoxc_Neural_InvalidNonce(nonce, $.operationalNonces[target]);
        }
        $.operationalNonces[target] = nonce;

        // 3. Execution (Rule 7)
        if (riskScore >= $.riskThreshold) {
            _executeIsolation($, target, selector, riskScore);
        }

        emit AoxcEvents.NeuralValidationSucceeded(
            structHash, msg.sender, AoxcConstants.REASON_DEFENSE_TRIGGER, riskScore
        );
    }

    /**
     * @dev Internal helper for isolation logic to reduce stack pressure.
     */
    function _executeIsolation(SentinelStorage storage $, address target, bytes4 selector, uint8 riskScore) internal {
        // Constitutional enforcement on Core
        try IAoxcCore($.coreAddress).setSectionalIsolation(selector, true) {} catch {}

        try IAoxcCore($.coreAddress).setRestrictionV2(target, true, "NEURAL_INTERCEPTION") {
            // Forward to Repair Engine if available
            if ($.repairEngine != address(0)) {
                try IAutoRepair($.repairEngine).triggerEmergencyQuarantine(selector, target) {
                    emit AoxcEvents.SystemRepairInitiated(keccak256("SENTINEL_REPAIR"), target);
                } catch {
                    _triggerRule10Emergency($);
                }
            }
        } catch {
            _triggerRule10Emergency($);
        }
    }

    function _triggerRule10Emergency(SentinelStorage storage $) internal {
        $.bastionSealed = true;
        _pause();
        emit AoxcEvents.GlobalLockStateChanged(true, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMINISTRATION
    //////////////////////////////////////////////////////////////*/

    function updateRiskThreshold(uint256 newThreshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newThreshold > 100) revert AoxcErrors.Aoxc_Neural_RiskTooHigh(uint8(newThreshold), 100);
        _getStore().riskThreshold = newThreshold;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // --- Audit View Methods ---
    function isBastionSealed() external view returns (bool) {
        return _getStore().bastionSealed;
    }

    function getOperationalNonce(address target) external view returns (uint256) {
        return _getStore().operationalNonces[target];
    }
}
