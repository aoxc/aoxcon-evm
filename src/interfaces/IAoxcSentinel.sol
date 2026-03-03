// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcSentinel
 * @author Aoxcore Security Architecture
 * @notice Interface for the Neural Sentinel AI security module.
 * @dev V3.0: The ultimate gatekeeper for the 10-Point Neural Handshake.
 */
interface IAoxcSentinel {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a 10-point handshake is neural-validated.
     * @param packetHash The keccak256 hash of the entire NeuralPacket.
     * @param riskScore The score calculated by the AI (0-255).
     * @param approved Boolean result of the neural gating.
     */
    event NeuralValidation(bytes32 indexed packetHash, uint8 riskScore, bool approved);

    /*//////////////////////////////////////////////////////////////
                            SECURITY LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 7, 8 & 10: Validates the entire 10-point handshake packet.
     * @dev This is the primary entry point for Core and other modules to verify AI approval.
     * @param packet The complete 10-point handshake data.
     * @return approved Returns true if the risk profile and signature are valid.
     */
    function validateNeuralPacket(IAoxcCore.NeuralPacket calldata packet) external view returns (bool approved);

    /**
     * @notice Rule 1 & 2: Legacy check for basic address-to-address permissions.
     * @dev Still used for secondary logic like Registry updates or low-value transfers.
     */
    function isAllowed(address from, address to) external view returns (bool approved);

    /**
     * @notice Rule 10: Direct verification of an EIP-712 neural signature.
     * @param hash The data hash (usually the packet hash).
     * @param signature The cryptographic seal from the AI Node.
     * @return isValid Returns true if the signature belongs to an authorized AI Sentinel Node.
     */
    function verifyNeuralSignature(bytes32 hash, bytes calldata signature) external view returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                            DIAGNOSTICS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 7: Retrieves the real-time risk score of a specific operation.
     * @param packetHash The unique hash of the NeuralPacket to check.
     * @return score Returns the risk value (0: Absolute Safe, 255: Critical/Attack).
     */
    function getRiskScore(bytes32 packetHash) external view returns (uint8 score);

    /**
     * @notice Checks if the AI Neural Bastion is online and synced with X Layer.
     */
    function isSentinelActive() external view returns (bool active);

    /**
     * @notice Rule 9: Returns the current AI model version hash.
     * @dev Used to ensure the Sentinel is using the correct 'ProtocolHash'.
     */
    function getModelProtocolHash() external view returns (bytes32);
}
