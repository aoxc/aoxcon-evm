// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcErrors
 * @author AOXCAN Neural Division
 * @notice Centralized Diagnostic Library for the Akdeniz v2.0.0 Ecosystem.
 * @dev
 * AUDIT DATA:
 * - Optimized via Custom Errors (EIP-6093 style) to minimize gas consumption.
 * - Categorized for seamless AI telemetry and off-chain monitoring.
 * - Implements dynamic slots for forward-compatibility with future V3/V4 modules.
 */
library AoxcErrors {
    /*//////////////////////////////////////////////////////////////
                        1. CORE: ACCESS & IDENTITY
    //////////////////////////////////////////////////////////////*/
    error Aoxc_AccessDenied();
    error Aoxc_Unauthorized(bytes32 role, address account);
    error Aoxc_InvalidAddress();
    error Aoxc_Blacklisted(address account);
    error Aoxc_ReentrancyIntercepted();
    error Aoxc_Neural_IdentityForgery(); // Signature or AI Proof mismatch

    /*//////////////////////////////////////////////////////////////
                        2. DYNAMIC MODULE EXTENSIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Generic error slot for future contracts not yet defined in this library.
     * @param moduleId The ID of the emitting contract (e.g., 10 for AI_GAMES).
     * @param errorCode The specific internal error code defined in that module.
     */
    error Aoxc_Module_Error(uint8 moduleId, uint16 errorCode);

    /**
     * @dev Catch-all for unplanned logic reverts with string descriptive data.
     */
    error Aoxc_CustomRevert(string reason);

    /*//////////////////////////////////////////////////////////////
                        3. NEURAL HANDSHAKE (10 LAWS)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Neural_InvalidOrigin(); // Rule 1: msg.sender check
    error Aoxc_Neural_InvalidTarget(); // Rule 2: Destination check
    error Aoxc_Neural_ValueMismatch(uint256 exp, uint256 act); // Rule 3: Balance/Value
    error Aoxc_Neural_InvalidNonce(uint256 prov, uint256 exp); // Rule 4: Replay protection
    error Aoxc_Neural_HandshakeExpired(uint256 dl, uint256 cur); // Rule 5: Time TTL
    error Aoxc_Neural_InvalidReasonCode(uint16 code); // Rule 6: Telemetry tagging
    error Aoxc_Neural_RiskTooHigh(uint8 score, uint8 limit); // Rule 7: AI Risk Threshold
    error Aoxc_Neural_RepairModeRequired(); // Rule 8: Emergency state
    error Aoxc_Neural_ProtocolMismatch(bytes32 exp, bytes32 act); // Rule 9: Versioning
    error Aoxc_Neural_SecurityVeto(address sentinel, uint256 risk); // Rule 10: AI Shutdown

    /*//////////////////////////////////////////////////////////////
                        4. FISCAL, VAULT & ASSETS
    //////////////////////////////////////////////////////////////*/
    error Aoxc_InsufficientBalance(uint256 avail, uint256 req);
    error Aoxc_ExceedsDailyLimit(uint256 req, uint256 rem);
    error Aoxc_TransferFailed();
    error Aoxc_ZeroAmount();
    error Aoxc_InflationHardcapReached();
    error Aoxc_Vault_Locked();
    error Aoxc_Vault_UnauthorizedWithdrawal();
    error Aoxc_Vault_SealBroken();

    /*//////////////////////////////////////////////////////////////
                        5. CPEX & EXCHANGE (FINANCE)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Cpex_InvalidPair();
    error Aoxc_Cpex_SlippageExceeded();
    error Aoxc_Cpex_InsufficientLiquidity();
    error Aoxc_Cpex_PriceOracleStale();
    error Aoxc_Cpex_CircuitBreakerTripped();

    /*//////////////////////////////////////////////////////////////
                        6. INFRASTRUCTURE & AUTO-REPAIR
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Repair_CooldownActive(uint256 remaining);
    error Aoxc_Repair_ModeActive();
    error Aoxc_Repair_ModeNotActive();
    error Aoxc_ExecutionFailed();
    error Aoxc_ChainNotSupported(uint256 chainId);
    error Aoxc_TemporalCollision(); // Block timestamp manipulation check
    error Aoxc_UpgradeBlockedBySentinel();

    /*//////////////////////////////////////////////////////////////
                        7. GOVERNANCE & NEURAL NEXUS
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Gov_QuorumNotMet(uint256 current, uint256 required);
    error Aoxc_Gov_ProposalNotActive(uint256 proposalId);
    error Aoxc_Gov_AlreadyVoted(address voter, uint256 proposalId);
    error Aoxc_Gov_VetoPeriodActive();
    error Aoxc_Gov_UnauthorizedProposer();
    error Aoxc_Gov_ActionDelayed();

    /*//////////////////////////////////////////////////////////////
                        8. REGISTRY & REPUTATION (CORE)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Registry_UserAlreadyRegistered();
    error Aoxc_Registry_CitizenNotFound();
    error Aoxc_Registry_ReputationTooLow(uint256 current, uint256 min);
    error Aoxc_Registry_IdentityExpired();

    /*//////////////////////////////////////////////////////////////
                        9. BRIDGE & ORACLE (FUTURE)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Bridge_InvalidSourceChain(uint256 chainId);
    error Aoxc_Bridge_MessageAlreadyProcessed(bytes32 msgHash);
    error Aoxc_Bridge_SyncOutdated();
    error Aoxc_Oracle_DataNotFound();
    error Aoxc_Oracle_ConsensusFailed();
}
