// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcAuditVoice (Neural V2.2)
 * @author AOXCAN Governance Division
 * @notice Community-driven Veto Signaling. Allows members to block malicious proposals.
 * @dev Optimized for OZ 5.0+ & ERC-7201. Implements Rule 10: Democratic Veto.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {IAoxcAuditVoice} from "aoxc-interfaces/IAoxcAuditVoice.sol";
import {IAoxcNexus} from "aoxc-interfaces/IAoxcNexus.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

contract AoxcAuditVoice is
    IAoxcAuditVoice,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE (DNA)
    //////////////////////////////////////////////////////////////*/

    struct AuditSignal {
        uint256 totalVetoPower;
        mapping(address => bool) hasSignaled;
        bool thresholdReached;
        uint256 finalizedAt;
        uint256 snapshotBlock;
    }

    struct AuditVoiceStore {
        address nexus;
        address aoxcToken;
        uint256 vetoThresholdBps;
        uint256 minimumVetoPower;
        mapping(uint256 => AuditSignal) proposalSignals;
    }

    // ERC-7201 Compliance
    bytes32 private constant AUDIT_VOICE_STORAGE_SLOT =
        0x89e5a1b068224578964573895245892345892345892345892345892345892300;

    function _getStore() internal pure returns (AuditVoiceStore storage $) {
        assembly { $.slot := AUDIT_VOICE_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeAuditVoiceV2(address admin, address nexus, address token) external initializer {
        if (admin == address(0) || nexus == address(0) || token == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();
        // __UUPSUpgradeable_init(); // REMOVED: Not present in OZ v5

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, admin);
        _grantRole(AoxcConstants.UPGRADER_ROLE, admin);

        AuditVoiceStore storage $ = _getStore();
        $.nexus = nexus;
        $.aoxcToken = token;
        $.vetoThresholdBps = 500; // 5% default
        $.minimumVetoPower = 1000 * 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                        VETO SIGNALING (CORE)
    //////////////////////////////////////////////////////////////*/

    function emitVetoSignal(uint256 proposalId) external override nonReentrant {
        AuditVoiceStore storage $ = _getStore();
        AuditSignal storage signal = $.proposalSignals[proposalId];

        if (signal.thresholdReached) revert AoxcErrors.Aoxc_CustomRevert("VETO: FINALIZED");
        if (signal.hasSignaled[msg.sender]) revert AoxcErrors.Aoxc_CustomRevert("VETO: ALREADY_SIGNALED");

        uint256 pastBlock = block.number - 1;
        uint256 power = IVotes($.aoxcToken).getPastVotes(msg.sender, pastBlock);

        if (power < $.minimumVetoPower) revert AoxcErrors.Aoxc_CustomRevert("VETO: INSUFFICIENT_POWER");

        if (signal.snapshotBlock == 0) {
            signal.snapshotBlock = pastBlock;
        }

        signal.hasSignaled[msg.sender] = true;
        signal.totalVetoPower += power;

        emit AoxcEvents.CommunityVetoSignaled(proposalId, signal.totalVetoPower);

        uint256 totalSupply = IVotes($.aoxcToken).getPastTotalSupply(signal.snapshotBlock);
        uint256 requiredThreshold = (totalSupply * $.vetoThresholdBps) / AoxcConstants.BPS_DENOMINATOR;

        if (signal.totalVetoPower >= requiredThreshold) {
            _executeIntervention($, proposalId, signal);
        }
    }

    function _executeIntervention(AuditVoiceStore storage $, uint256 proposalId, AuditSignal storage signal) internal {
        signal.thresholdReached = true;
        signal.finalizedAt = block.timestamp;

        // NeuralPacket construction for IAoxcNexus compliance
        IAoxcCore.NeuralPacket memory packet = IAoxcCore.NeuralPacket({
            riskScore: 255, // Max danger
            reason: "COMMUNITY_VETO_ACTIVE",
            metadata: ""
        });

        try IAoxcNexus($.nexus).processNeuralVeto(proposalId, packet) {
            emit AoxcEvents.KarujanNeuralVeto(proposalId, 255);
        } catch {
            emit AoxcEvents.AutonomousCorrectionFailed(
                keccak256("VETO_INTERVENTION"), "NEXUS_UNREACHABLE", block.timestamp
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function isVetoed(uint256 proposalId) external view override returns (bool) {
        return _getStore().proposalSignals[proposalId].thresholdReached;
    }

    function getVetoSignalStatus(uint256 proposalId) external view override returns (uint256 power, bool reached) {
        AuditSignal storage signal = _getStore().proposalSignals[proposalId];
        return (signal.totalVetoPower, signal.thresholdReached);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMINISTRATION
    //////////////////////////////////////////////////////////////*/

    function configureVetoThreshold(uint256 bps) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        if (bps < 100 || bps > 5000) revert AoxcErrors.Aoxc_InvalidThreshold();
        _getStore().vetoThresholdBps = bps;
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
