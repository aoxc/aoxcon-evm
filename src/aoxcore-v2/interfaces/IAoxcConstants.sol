// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAoxcConstants
 * @author AOXCAN
 * @notice Interface for the centralized constants of the Akdeniz v3.0.0 Neural Ecosystem.
 * @dev Rule 7 & 9: Provides the final "Guardrails" for the AI and Governance logic.
 */
interface IAoxcConstants {
    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL ROLES
    //////////////////////////////////////////////////////////////*/
    function COMPLIANCE_ROLE() external pure returns (bytes32);
    function EMERGENCY_ROLE() external pure returns (bytes32);
    function GOVERNANCE_ROLE() external pure returns (bytes32);
    function GUARDIAN_ROLE() external pure returns (bytes32);
    function MINTER_ROLE() external pure returns (bytes32);
    function REPAIR_ROLE() external pure returns (bytes32);
    function SENTINEL_ROLE() external pure returns (bytes32);
    function TREASURY_ROLE() external pure returns (bytes32);
    function UPGRADER_ROLE() external pure returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                        AI & NEURAL SENTINEL
    //////////////////////////////////////////////////////////////*/
    function AI_MAX_FREEZE_DURATION() external pure returns (uint256);
    function NEURAL_HEARTBEAT_TIMEOUT() external pure returns (uint256);
    function NEURAL_PACKET_LIFETIME() external pure returns (uint256); // Rule 5

    // Neural Risk Calibration (Rule 7: 0-255)
    function NEURAL_RISK_SAFE() external pure returns (uint8);
    function NEURAL_RISK_MEDIUM() external pure returns (uint8);
    function NEURAL_RISK_CRITICAL() external pure returns (uint8);
    function NEURAL_RISK_MAX() external pure returns (uint8);

    /*//////////////////////////////////////////////////////////////
                        FISCAL & STAKING LIMITS
    //////////////////////////////////////////////////////////////*/
    function BPS_DENOMINATOR() external pure returns (uint256);
    function MIN_STAKE_DURATION() external pure returns (uint256);
    function STAKING_REWARD_APR_BPS() external pure returns (uint256);
    function REPAIR_TIMELOCK() external pure returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & PROTOCOL
    //////////////////////////////////////////////////////////////*/
    function CHAIN_ID_X_LAYER() external pure returns (uint256);
    function DAO_NAME() external pure returns (string memory);
    function PROTOCOL_VERSION() external pure returns (bytes32);
    function NEURAL_V3_HASH() external pure returns (bytes32); // Rule 9
    function TOKEN_SYMBOL() external pure returns (string memory);
}
