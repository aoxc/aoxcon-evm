// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCpex} from "aoxc-interfaces/IAoxcCpex.sol";
import {IAoxcBuild} from "aoxc-interfaces/IAoxcBuild.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";

/**
 * @title  AoxcStorage
 * @author AOXCAN Infrastructure
 * @notice Centralized optimized storage using ERC-7201 Namespace Pattern.
 * @dev    V3.1 - Hardened: Optimized slot packing & explicit upgrade gaps.
 */
abstract contract AoxcStorage {
    /*//////////////////////////////////////////////////////////////
                        V3 NEURAL STRUCTURES (DNA)
    //////////////////////////////////////////////////////////////*/

    struct NeuralPacket {
        address origin; // 20 bytes
        address target; // 20 bytes
        uint256 value; // 32 bytes
        uint256 nonce; // 32 bytes
        uint256 deadline; // 32 bytes
        bytes32 protocolHash; // 32 bytes
        uint16 reasonCode; // 2 bytes
        uint8 riskScore; // 1 byte
        bool autoRepairMode; // 1 byte
        bytes neuralSignature; // Dynamic bytes (keep at end)
    }

    /*//////////////////////////////////////////////////////////////
                           SHARED STRUCTURES
    //////////////////////////////////////////////////////////////*/

    struct CitizenRecord {
        uint256 citizenId; // Slot 0
        uint256 reputation; // Slot 1
        uint256 totalVoted; // Slot 2
        uint64 joinedAt; // \
        uint64 lastPulse; //  |-- Sıkıştırılmış Slot (Slot 3)
        uint8 tier; //  |
        bool isBlacklisted; // /
        string blacklistReason; // Slot 4+ (Dynamic)
    }

    struct PatchCore {
        address targetContract; // 20 bytes
        address candidateLogic; // 20 bytes
        bytes4 functionSelector; // 4 bytes
        uint64 timestamp; // 8 bytes
        uint64 autoUnlockAt; // 8 bytes
        bool isQuarantined; // 1 byte
    }

    struct NeuralCellV2 {
        uint256 cellId;
        bytes32 cellHash;
        uint256 memberCount;
        uint256 lockExpiry;
        bool isQuarantined;
    }

    struct ProposalCore {
        address proposer; // 20 bytes
        uint64 startTime; // 8 bytes
        uint64 endTime; // 8 bytes
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
        uint256 totalMinted;
        uint256 reserveRatio;
        address tokenAddress;
        IAoxcBuild.AssetType aType;
        bool isMintingActive;
        bytes32 docHash;
    }

    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE LAYOUTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @custom:storage-location erc7201:aoxc.main.storage.v2
     */
    struct MainStorage {
        address nexusHub;
        address sentinelAi;
        address repairEngine;
        address aoxcToken;
        address coreAssetToken;
        address neuralSentinelNode;
        address treasury;
        uint256 operationalNonce;
        uint256 dailyTransferLimit;
        uint256 anchorSupply;
        uint256 mintedThisYear;
        uint256 repairExpiry;
        bytes32 activeProtocolHash;
        uint64 lastPulseTimestamp;
        bool globalLock;
        bool aiFailSafeActive;
        bool isSovereignVaultSealed;
        bool isRepairModeActive;
        mapping(address => uint256) userNonces;
        mapping(address => bool) isExcludedFromLimits;
        mapping(address => uint256) lastActionBlock;
        mapping(address => uint256) lastTransferDay;
        mapping(address => uint256) dailySpent;
    }

    /**
     * @custom:storage-location erc7201:aoxc.registry.storage.v2
     */
    struct RegistryStorageV2 {
        mapping(address => CitizenRecord) citizenRecords;
        mapping(bytes4 => mapping(address => PatchCore)) activePatches;
        mapping(uint256 => NeuralCellV2) cells;
        mapping(address => uint256) userToCellMap;
        mapping(uint256 => SovereignAsset) assets;
        uint256 totalCells;
        uint256 activeCellPointer;
        uint256 totalOps;
        bytes32 lastCellHash;
    }

    /**
     * @custom:storage-location erc7201:aoxc.nexus.storage.v2
     */
    struct NexusParamsV2 {
        address aoxcToken;
        uint256 votingDelay;
        uint256 votingPeriod;
        uint256 quorumNumerator;
        bytes32 domainSeparator;
        mapping(uint256 => ProposalCore) proposals;
        mapping(uint256 => mapping(address => bool)) hasVoted;
    }

    /**
     * @custom:storage-location erc7201:aoxc.staking.storage.v2
     */
    struct StakingStorage {
        uint256 totalValueLocked;
        uint256 baseYieldRateBps;
        uint256 attritionPenaltyBps;
        uint256 minLockdownDuration;
        bool stakingEnabled;
        mapping(address => IAoxcCpex.PositionInfo[]) accountPositions;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE ACCESSORS
    //////////////////////////////////////////////////////////////*/

    function _getMainStorage() internal pure virtual returns (MainStorage storage ms) {
        bytes32 slot = AoxcConstants.MAIN_STORAGE_SLOT;
        assembly { ms.slot := slot }
    }

    function _getRegistryV2() internal pure virtual returns (RegistryStorageV2 storage rs) {
        bytes32 slot = AoxcConstants.REGISTRY_V2_SLOT;
        assembly { rs.slot := slot }
    }

    function _getNexusStore() internal pure virtual returns (NexusParamsV2 storage ns) {
        bytes32 slot = AoxcConstants.NEXUS_V2_SLOT;
        assembly { ns.slot := slot }
    }

    function _getStakingStorage() internal pure virtual returns (StakingStorage storage ss) {
        bytes32 slot = AoxcConstants.STAKING_STORAGE_SLOT;
        assembly { ss.slot := slot }
    }

    // Future-proofing: Her kontrat için storage gap
    uint256[50] private __gap;
}
