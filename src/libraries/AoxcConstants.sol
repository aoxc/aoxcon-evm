// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcConstants
 * @author AOXCAN
 * @notice Centralized constants for the Akdeniz v2.0.0 DAO Ecosystem.
 * @dev Pro-Level: Future-proof roles and neural risk parameters integrated.
 */
library AoxcConstants {
    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL ROLES (EXTENDED)
    //////////////////////////////////////////////////////////////*/
    bytes32 internal constant COMPLIANCE_ROLE = keccak256("Aoxc.ROLE.COMPLIANCE");
    bytes32 internal constant EMERGENCY_ROLE = keccak256("Aoxc.ROLE.EMERGENCY");
    bytes32 internal constant GOVERNANCE_ROLE = keccak256("Aoxc.ROLE.GOVERNANCE");
    bytes32 internal constant GUARDIAN_ROLE = keccak256("Aoxc.ROLE.GUARDIAN");
    bytes32 internal constant MINTER_ROLE = keccak256("Aoxc.ROLE.MINTER");
    bytes32 internal constant REPAIR_ROLE = keccak256("Aoxc.ROLE.REPAIR_MASTER");
    bytes32 internal constant SENTINEL_ROLE = keccak256("Aoxc.ROLE.SENTINEL");
    bytes32 internal constant TREASURY_ROLE = keccak256("Aoxc.ROLE.TREASURY");
    bytes32 internal constant UPGRADER_ROLE = keccak256("Aoxc.ROLE.UPGRADER");

    // Future Expansion Roles
    bytes32 internal constant ORACLE_ROLE = keccak256("Aoxc.ROLE.ORACLE"); // For AI data feeds
    bytes32 internal constant BRIDGE_ROLE = keccak256("Aoxc.ROLE.BRIDGE"); // For X Layer Cross-chain
    bytes32 internal constant LIQUIDITY_ROLE = keccak256("Aoxc.ROLE.LIQUIDITY"); // For AoxcChange engine
    bytes32 internal constant ARCHITECT_ROLE = keccak256("Aoxc.ROLE.ARCHITECT"); // For Factory V3 upgrades

    /*//////////////////////////////////////////////////////////////
                        AI & NEURAL SENTINEL (V3)
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant AI_MAX_FREEZE_DURATION = 24 hours;
    uint256 internal constant AI_MIN_PULSE_INTERVAL = 1 hours;
    uint256 internal constant NEURAL_HEARTBEAT_TIMEOUT = 3 days;
    uint256 internal constant NEURAL_PACKET_LIFETIME = 15 minutes;

    // Neural Risk Calibration (Rule 7: 0-255 Scale)
    uint8 internal constant NEURAL_RISK_SAFE = 50;
    uint8 internal constant NEURAL_RISK_MEDIUM = 100;
    uint8 internal constant NEURAL_RISK_CRITICAL = 200;
    uint8 internal constant NEURAL_RISK_MAX = 255;

    /*//////////////////////////////////////////////////////////////
                        REASON CODES (Neural Telemetry)
    //////////////////////////////////////////////////////////////*/
    uint16 internal constant REASON_GENERIC_OP = 100;
    uint16 internal constant REASON_TREASURY_OUT = 200;
    uint16 internal constant REASON_MERIT_REWARD = 300;
    uint16 internal constant REASON_MIGRATION_OUT = 400;
    uint16 internal constant REASON_DEFENSE_TRIGGER = 500;
    uint16 internal constant REASON_VOTE_VETO = 700; // AI Veto reason
    uint16 internal constant REASON_EMERGENCY_PATCH = 911;

    /*//////////////////////////////////////////////////////////////
                        ERC-7201 STORAGE SLOTS
    //////////////////////////////////////////////////////////////*/
    bytes32 internal constant BUILD_STORAGE_SLOT = keccak256("Aoxc.Storage.Build.v1");
    bytes32 internal constant MAIN_STORAGE_SLOT = 0x27f884a8677c731e8093d6e5a4073f1d8595531d054d5d71c1815e98544e3d00;
    bytes32 internal constant NEXUS_V2_SLOT = keccak256("Aoxc.Storage.Nexus.v2");
    bytes32 internal constant REGISTRY_V2_SLOT = 0x4d6368d14745c479549f50e8544e877e59b9511d124d5d71c1815e98544e3000;
    bytes32 internal constant STAKING_STORAGE_SLOT = 0x07f15e855018f36c53e04a43f8e5276e09968412676063467472173957291a00;
    bytes32 internal constant VAULT_V2_SLOT = keccak256("Aoxc.Storage.Vault.v2");

    /*//////////////////////////////////////////////////////////////
                        FISCAL & STAKING LIMITS
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant ATTRITION_PENALTY_BPS = 1000;
    uint256 internal constant BPS_DENOMINATOR = 10000;
    uint256 internal constant DUST_THRESHOLD = 1e15;
    uint256 internal constant MAX_MINT_PER_YEAR_BPS = 200;
    uint256 internal constant MAX_TRANSFER_BPS = 50;
    uint256 internal constant MIN_STAKE_DURATION = 90 days;
    uint256 internal constant STAKING_REWARD_APR_BPS = 1200;

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & PROTOCOL
    //////////////////////////////////////////////////////////////*/
    uint256 internal constant CHAIN_ID_X_LAYER = 196;
    uint256 internal constant CHAIN_ID_ETH_MAINNET = 1;
    string internal constant DAO_NAME = "AoxcCore Sovereign Assembly";
    uint256 internal constant GENESIS_CELL_ID = 1;
    uint256 internal constant GOVERNANCE_QUORUM_BPS = 400;
    uint256 internal constant MAX_CELL_MEMBERS = 100;
    uint256 internal constant PROPOSAL_THRESHOLD_BPS = 100;
    bytes32 internal constant PROTOCOL_VERSION = "2.0.0-AKDENIZ";
    bytes32 internal constant NEURAL_V3_HASH = keccak256("Aoxc.Protocol.V3.Neural");
    uint256 internal constant REPAIR_TIMELOCK = 2 days;

    /*//////////////////////////////////////////////////////////////
                        AOXC ASSET PARAMETERS
    //////////////////////////////////////////////////////////////*/
    string internal constant TOKEN_NAME = "AoxcCore Token";
    string internal constant TOKEN_SYMBOL = "AOXC";
    uint8 internal constant TOKEN_DECIMALS = 18;
}
