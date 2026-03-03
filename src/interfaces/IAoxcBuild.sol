// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcBuild
 * @author Aoxcore Security Architecture
 * @notice Factory for Neural Assets and Autonomous Patch Implementation.
 * @dev Governed by the 10-Point Neural Handshake to ensure build integrity.
 */
interface IAoxcBuild {
    enum AssetType {
        IDENTITY, // Neural Identity tokens
        RWA_POINTER, // Real World Asset links
        SBT_BADGE, // Soulbound reputation badges
        AI_AGENT_KEY // Keys for Autonomous AI Agents
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetBuilt(address indexed to, uint256 indexed assetId, AssetType aType, uint8 riskScore);
    event SystemRepairInitiated(bytes32 indexed anomalyHash, address indexed target, uint16 reasonCode);
    event PatchExecuted(bytes4 indexed selector, address indexed target, address patchLogic, uint256 nonce);

    /*//////////////////////////////////////////////////////////////
                            BUILD OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 3 & 7: Deploys a new neural asset or RWA pointer.
     * @param to The recipient of the newly built asset.
     * @param aType The category of the asset (IDENTITY, RWA, etc.)
     * @param doc Merkle root or document hash linked to the asset.
     * @param initialVal Starting valuation or power of the asset.
     * @param packet The 10-point handshake verifying minting authority.
     */
    function buildAsset(
        address to,
        AssetType aType,
        bytes32 doc,
        uint256 initialVal,
        IAoxcCore.NeuralPacket calldata packet
    ) external returns (uint256 assetId);

    /*//////////////////////////////////////////////////////////////
                        REPAIR & PATCH DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 8 & 10: Isolates a compromised function immediately.
     */
    function triggerEmergencyQuarantine(bytes4 selector, address target, IAoxcCore.NeuralPacket calldata packet)
        external;

    /**
     * @notice Rule 9: Deploys a cryptographic patch to a target contract.
     * @param anomalyId ID of the detected flaw.
     * @param selector Function signature being redirected.
     * @param target Contract being patched.
     * @param patchLogic Address of the new verified logic.
     * @param packet The 10-point handshake confirming AI Sentinel & Protocol Hash.
     */
    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        IAoxcCore.NeuralPacket calldata packet
    ) external;

    /**
     * @notice Rules 5 & 6: Restores normal operation after a patch is verified.
     */
    function liftQuarantine(bytes4 selector, address target, IAoxcCore.NeuralPacket calldata packet) external;
}
