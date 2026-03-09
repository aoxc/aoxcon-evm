// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcCpex
 * @author AoxcAN AI Architect
 * @notice Enterprise-grade yield engine with Neural-Pulse Reputation Scaling.
 * @dev V3.0: Enforces the 10-Point Neural Handshake for secure staking and meritocracy.
 */
interface IAoxcCpex {
    /**
     * @dev User's unique staking position metadata.
     * Packed for Gas Efficiency: [principal(128) | entryTime(64) | lockPeriod(64)] = 256 bits (1 Slot)
     */
    struct PositionInfo {
        uint128 principal; // Rule 3: Amount of tokens locked
        uint64 entryTime; // Rule 5: Block timestamp at initiation
        uint64 lockPeriod; // Mandatory duration in seconds
        uint64 neuralBoost; // Rule 7: AI-assigned multiplier (Basis Points)
        bool isActive; // Operational status
    }

    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(address indexed user, uint256 indexed index, uint256 amount, uint8 riskScore);
    event PositionClosed(address indexed user, uint256 returned, uint256 burned, uint256 nonce);
    event NeuralBoostApplied(address indexed user, uint256 boostFactor, uint16 reasonCode);
    event YieldRateUpdated(uint256 oldRate, uint256 newRate, bytes32 protocolHash);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 3, 5 & 7: Initiates a staking position with a Neural Handshake.
     * @param amount Amount of AoxcCore tokens to lock.
     * @param duration Lockdown duration.
     * @param packet The 10-point handshake verifying the user's intent and AI approval.
     */
    function openPosition(uint256 amount, uint256 duration, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 4, 10: Finalizes a position and releases principal/yield.
     * @param index The index of the position to close.
     * @param packet The 10-point handshake verifying the cooldown and release authority.
     */
    function closePosition(uint256 index, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                        DEFENSIVE & ANALYTIC VIEWS
    //////////////////////////////////////////////////////////////*/

    function calculateYield(address user, uint256 index) external view returns (uint256 yield);
    function getAccountMerit(address user) external view returns (uint256 merit);
    function getPexLockState() external view returns (bool isLocked, uint256 expiry);
    function getPositionDetails(address user, uint256 index) external view returns (PositionInfo memory);
    function getModuleTvl() external view returns (uint256);
    function getPositionCount(address user) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & SYSTEM OPS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 9: Updates the base yield rate via global protocol hash verification.
     */
    function updateBaseYield(uint256 newRateBps, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 8 & 10: Updates the AI Node authorized for CPEX signatures.
     */
    function updateAiNode(address newNode, IAoxcCore.NeuralPacket calldata packet) external;
}
