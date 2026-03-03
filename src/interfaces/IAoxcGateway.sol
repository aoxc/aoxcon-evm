// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcGATEWAY
 * @author Aoxcore Security Architecture
 * @notice Interface for Autonomous Cross-Chain Migrations and Neural Vetting.
 * @dev V3.0: Enforces 10-Point Neural Handshake to eliminate bridge-drain attacks.
 */
interface IAoxcGATEWAY {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MigrationInitiated(
        uint16 indexed dstChainId,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 migrationId,
        uint8 riskScore
    );

    event MigrationInFinalized(
        uint16 indexed srcChainId, address indexed to, uint256 amount, bytes32 migrationId, uint256 nonce
    );

    event NeuralAnomalyNeutralized(bytes32 indexed migrationId, uint8 riskScore, uint16 reasonCode);

    /*//////////////////////////////////////////////////////////////
                        MIGRATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 2, 3 & 7: Initiates an outbound migration with AI risk check.
     * @param dstChainId Destination network ID.
     * @param to Recipient address on the destination chain.
     * @param amount Amount of assets to migrate.
     * @param packet The 10-point handshake verifying the source-chain's authority.
     */
    function initiateMigration(uint16 dstChainId, address to, uint256 amount, IAoxcCore.NeuralPacket calldata packet)
        external
        payable;

    /**
     * @notice Rule 10: Finalizes an inbound migration via AI cryptographic proof.
     * @param srcChainId Source network ID.
     * @param to Recipient address on X Layer.
     * @param amount Amount of assets arriving.
     * @param migrationId Unique ID for the cross-chain transaction.
     * @param packet The 10-point handshake confirming the validity of the inbound message.
     */
    function finalizeMigration(
        uint16 srcChainId,
        address to,
        uint256 amount,
        bytes32 migrationId,
        IAoxcCore.NeuralPacket calldata packet
    ) external;

    /*//////////////////////////////////////////////////////////////
                            GATEWAY ANALYTICS
    //////////////////////////////////////////////////////////////*/

    function getGatewayLockState() external view returns (bool isLocked, uint256 expiry);

    /**
     * @notice Returns the required native fee for cross-chain transmission.
     */
    function quoteGatewayFee(uint16 dstChainId, uint256 amount) external view returns (uint256 nativeFee);

    /**
     * @notice Rule 3: Returns the remaining 'Quantum' (liquidity limit) for a chain.
     */
    function getRemainingQuantum(uint16 chainId, bool isOutbound) external view returns (uint256 remaining);

    function isNetworkSupported(uint16 chainId) external view returns (bool);
    function migrationProcessed(bytes32 migrationId) external view returns (bool);

    /**
     * @notice Rule 9: Validates if the gateway protocol is in sync with Core.
     */
    function getGatewayProtocolHash() external view returns (bytes32);
}
