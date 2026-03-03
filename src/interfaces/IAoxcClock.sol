// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcClock
 * @author Aoxcore Security Architecture
 * @notice Autonomous Time-Lock and Risk-Based Scheduling Engine.
 * @dev V3.0: Enforces the 10-Point Neural Handshake on all time-sensitive operations.
 */
interface IAoxcClock {
    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event OperationScheduled(bytes32 indexed id, address target, uint256 value, uint256 delay, uint8 riskScore);
    event OperationExecuted(bytes32 indexed id, address target, uint256 value);
    event OperationCancelled(bytes32 indexed id, uint16 reasonCode);
    event NeuralRiskEscalation(bytes32 indexed operationId, uint256 riskScore, uint256 newDelay);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 4 & 7: Schedules an operation with a risk-adjusted delay.
     * @param target The contract to interact with.
     * @param value Native asset value involved.
     * @param data The function call data.
     * @param predecessor ID of a previous operation that must finish first.
     * @param salt Unique salt for hash generation.
     * @param packet The 10-point handshake determining initial risk and delay.
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        IAoxcCore.NeuralPacket calldata packet
    ) external;

    /**
     * @notice Rule 7, 8 & 10: Dynamically increases delay if AI detects rising risk.
     * @param id The operation ID to escalate.
     * @param packet The 10-point handshake providing the new RiskScore and AI signature.
     */
    function neuralEscalation(bytes32 id, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 5 & 10: Executes a matured operation.
     * @param packet The 10-point handshake verifying the execution window.
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        IAoxcCore.NeuralPacket calldata packet
    ) external payable;

    /**
     * @notice Rule 6 & 8: Cancels a pending operation due to security threats.
     */
    function cancel(bytes32 id, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                            CLOCK ANALYTICS
    //////////////////////////////////////////////////////////////*/

    function isOperation(bytes32 id) external view returns (bool);
    function isOperationPending(bytes32 id) external view returns (bool);
    function isOperationReady(bytes32 id) external view returns (bool);
    function isOperationDone(bytes32 id) external view returns (bool);

    function getClockLockState() external view returns (bool isLocked, uint256 expiry);
    function getMinDelayForTarget(address target) external view returns (uint256 duration);
    function getTimestamp(bytes32 id) external view returns (uint256 timestamp);

    /**
     * @notice Rule 9: Validates operation hash against protocol standards.
     */
    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        pure
        returns (bytes32 hash);

    /*//////////////////////////////////////////////////////////////
                        SECURITY CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets mandatory minimum delay for high-risk targets.
     */
    function setTargetSecurityTier(address target, uint256 minDelay, IAoxcCore.NeuralPacket calldata packet) external;
}
