// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AoxcStorage} from "../abstract/AoxcStorage.sol";
import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcRegistry
 * @author AoxcAN AI Architect
 * @notice Global Ledger for AI-driven autonomous identity and reputation.
 * @dev V3.0: Enforces the 10-Point Neural Handshake for every social and state change.
 */
interface IAoxcRegistry {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ReputationUpdated(address indexed member, uint256 oldRep, uint256 newRep, uint16 reasonCode);
    event MemberOnboarded(address indexed member, uint256 indexed cellId, uint8 riskScore);
    event NeuralQuarantineTriggered(address indexed target, uint256 riskScore, uint256 indexed cellId);
    event NeuralAnomalyDetected(address indexed member, bytes32 alertCode, uint256 nonce);

    /*//////////////////////////////////////////////////////////////
                            READ OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function isMemberOperational(address member) external view returns (bool);
    function userToCellMap(address user) external view returns (uint256);
    function cellLockdown(uint256 cellId) external view returns (bool);
    function getCitizenRecord(address member) external view returns (AoxcStorage.CitizenRecord memory);

    function getReputationParams() external view returns (uint256 maxRep, uint256 qThreshold, uint256 rThreshold);
    function getActiveCell() external view returns (uint256);
    function getQuantumLimits() external view returns (uint256 minQuantum, uint256 maxQuantum);

    /*//////////////////////////////////////////////////////////////
                        NEURAL & AI OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 4 & 10: Onboards a new member to the neural network.
     * @param member The address to register.
     * @param packet The 10-point handshake verifying identity legitimacy.
     */
    function onboardMember(address member, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 3, 6 & 7: Adjusts reputation based on AI-DAO behavior.
     * @dev This is the function that caused previous build errors. Now unified.
     * @param member Target address.
     * @param adjustment Amount to add/subtract (e.g., +100, -50).
     * @param packet The 10-point handshake providing reasonCode and riskScore.
     */
    function adjustReputation(address member, int256 adjustment, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 8 & 10: Triggers lockdown for a specific network cell.
     */
    function triggerCellLockdown(uint256 cellId, bool status, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 7: Reports an anomaly detected by off-chain neural nodes.
     */
    function reportNeuralAnomaly(address member, bytes32 alertCode, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                            SYSTEM CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 9: Emergency pause of the entire registry state.
     */
    function pauseRegistry(bool status, IAoxcCore.NeuralPacket calldata packet) external;
}
