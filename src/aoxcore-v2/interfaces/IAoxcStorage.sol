// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcBuild} from "aoxc-interfaces/IAoxcBuild.sol";

/**
 * @title IAoxcStorage
 * @author AOXCAN
 * @notice Global interface for AOXC Ecosystem data structures.
 * @dev Rule 1-10: Contains the Master NeuralPacket and shared records.
 */
interface IAoxcStorage {
    /*//////////////////////////////////////////////////////////////
                        V3 NEURAL STRUCTURES (DNA)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The Master Handshake structure that passes through all modules.
     */
    struct NeuralPacket {
        address origin; // Rule 1: Sender/Initiator
        address target; // Rule 2: Contract being called
        uint256 value; // Rule 3: Asset amount/value
        uint256 nonce; // Rule 4: Anti-replay counter
        uint256 deadline; // Rule 5: Time-lock validity
        uint16 reasonCode; // Rule 6: Diagnostic operation code
        uint8 riskScore; // Rule 7: AI Risk Assessment (0-255)
        bool autoRepairMode; // Rule 8: Self-healing state flag
        bytes32 protocolHash; // Rule 9: Codebase integrity hash
        bytes neuralSignature; // Rule 10: AI Sentinel cryptographic seal
    }

    /*//////////////////////////////////////////////////////////////
                            SHARED STRUCTURES
    //////////////////////////////////////////////////////////////*/

    struct CitizenRecord {
        uint256 citizenId;
        uint64 joinedAt;
        uint8 tier;
        uint256 reputation;
        uint64 lastPulse;
        uint256 totalVoted;
        bool isBlacklisted;
        string blacklistReason;
    }

    struct PatchCore {
        address targetContract;
        bytes4 functionSelector;
        uint64 timestamp;
        address candidateLogic;
        uint64 autoUnlockAt;
        bool isQuarantined;
    }

    struct NeuralCellV2 {
        uint256 cellId;
        bytes32 cellHash;
        uint256 memberCount;
        bool isQuarantined;
        uint256 lockExpiry;
    }

    struct ProposalCore {
        address proposer;
        uint64 startTime;
        uint64 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 riskScore;
        uint256 aiRiskScore;
        uint256 snapshot;
        bool exists;
        bool executed;
        bool vetoed;
        bool queued;
    }

    struct SovereignAsset {
        uint256 assetId;
        IAoxcBuild.AssetType aType;
        address tokenAddress;
        uint256 totalMinted;
        uint256 reserveRatio;
        bool isMintingActive;
        bytes32 docHash;
    }
}
