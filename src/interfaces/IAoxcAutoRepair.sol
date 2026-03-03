// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcAutoRepair
 * @author Aoxcore Security Architecture
 * @notice Autonomous Recovery and Self-Healing Interface.
 * @dev Integrated with the 10-Point Neural Handshake to prevent malicious patches.
 */
interface IAoxcAutoRepair {
    /**
     * @notice Triggered when a function or address is quarantined.
     */
    event SystemQuarantined(bytes4 indexed selector, address indexed target, uint16 reasonCode);

    /**
     * @notice Triggered when a neural patch is successfully applied.
     */
    event NeuralPatchApplied(uint256 indexed anomalyId, address patchLogic, uint8 riskScore);

    /**
     * @notice Rules 1, 2, 7 & 8: Puts a specific function or target into safety isolation.
     * @param selector The function identifier to block.
     * @param target The address being isolated.
     * @param packet The 10-point handshake proof confirming the anomaly.
     */
    function triggerEmergencyQuarantine(bytes4 selector, address target, IAoxcCore.NeuralPacket calldata packet)
        external;

    /**
     * @notice Rules 3, 9 & 10: Executes an autonomous logic swap (patch).
     * @param anomalyId Unique ID for the detected system error.
     * @param selector The function signature being repaired.
     * @param target The target contract receiving the fix.
     * @param patchLogic The address of the temporary fix contract.
     * @param packet The 10-point handshake confirming AI Sentinel approval.
     */
    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        IAoxcCore.NeuralPacket calldata packet
    ) external;

    /**
     * @notice Rules 5 & 6: Re-enables a quarantined function after verification.
     * @param packet The 10-point handshake confirming system stability.
     */
    function liftQuarantine(bytes4 selector, address target, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                            RECOVERY ANALYTICS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks if a function is safe to call (not in quarantine).
     */
    function isOperational(bytes4 selector) external view returns (bool);

    /**
     * @notice Returns current repair mode status and AI-calculated expiration.
     */
    function getRepairStatus() external view returns (bool inRepairMode, uint256 expiry);

    /**
     * @notice Rule 9: Validates if a patch is verified against the current protocol hash.
     */
    function validatePatch(uint256 anomalyId) external view returns (bool isVerified);
}
