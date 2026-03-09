// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcAuditVoice
 * @author Aoxcore Security Architecture
 * @notice Interface for the Autonomous Community Veto and AI Audit Analysis.
 * @dev Fully integrated with the 10-Point Neural Handshake (v3.0).
 */
interface IAoxcAuditVoice {
    /**
     * @notice Triggered when a proposal or action is flagged by the community or AI.
     * @param proposalId Unique identifier for the audited action.
     * @param totalVetoPower Current accumulated power against the action.
     * @param riskScore AI-calculated risk level at the time of signal.
     */
    event CommunityVetoSignaled(uint256 indexed proposalId, uint256 totalVetoPower, uint8 riskScore);

    /**
     * @notice Records the audit trace for a specific Neural Packet.
     * @param packet The 10-point handshake data being audited.
     */
    function recordAuditTrace(IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Returns if a specific action (via its ID) has been officially vetoed.
     * @dev Rule 8 (AutoRepair) and Rule 7 (RiskScore) are checked here.
     */
    function isVetoed(uint256 proposalId) external view returns (bool);

    /**
     * @notice Gets detailed veto status.
     * @return power The current veto weight.
     * @return reached Boolean if the threshold to block the action is met.
     */
    function getVetoSignalStatus(uint256 proposalId) external view returns (uint256 power, bool reached);

    /**
     * @notice Emits a veto signal against an action using the 10-point protocol.
     * @dev Must verify Rule 10 (NeuralSignature) before allowing a community signal.
     * @param proposalId The ID of the action/proposal to veto.
     * @param packet The handshake proof validating the sender's right to signal.
     */
    function emitVetoSignal(uint256 proposalId, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Validates Rule 9 (ProtocolHash) compatibility for the audit module.
     */
    function getAuditProtocolVersion() external view returns (bytes32);
}
