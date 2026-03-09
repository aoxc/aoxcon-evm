// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcErrors
 * @author AOXCAN Neural Division
 * @notice AOXC Otonom Ekosistemi için Merkezi Diyagnostik Kütüphanesi.
 * @dev Gaz tüketimini minimize etmek için Custom Error (EIP-6093) kullanılmıştır.
 */
library AoxcErrors {
    /*//////////////////////////////////////////////////////////////
                        1. CORE: ACCESS & IDENTITY
    //////////////////////////////////////////////////////////////*/
    error Aoxc_AccessDenied();
    error Aoxc_Unauthorized(bytes32 role, address account);
    error Aoxc_InvalidAddress();
    error Aoxc_Blacklisted(address account, string reason);
    error Aoxc_ReentrancyIntercepted();
    error Aoxc_Neural_IdentityForgery(); 
    error Aoxc_GlobalLockActive();

    /*//////////////////////////////////////////////////////////////
                        2. DYNAMIC MODULE EXTENSIONS
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Module_Error(uint8 moduleId, uint16 errorCode);
    error Aoxc_CustomRevert(string reason);

    /*//////////////////////////////////////////////////////////////
                        3. NEURAL HANDSHAKE (10 LAWS)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Neural_InvalidOrigin(); 
    error IAoxcSentinel_Neural_InvalidOrigin();
    error Aoxc_Neural_InvalidTarget(); 
    error Aoxc_Neural_ValueMismatch(uint256 expected, uint256 actual); 
    error Aoxc_Neural_InvalidNonce(uint256 provided, uint256 expected); 
    error Aoxc_Neural_HandshakeExpired(uint256 deadline, uint256 current); 
    error Aoxc_Neural_InvalidReasonCode(uint16 code); 
    error Aoxc_Neural_RiskTooHigh(uint8 score, uint8 limit); 
    error Aoxc_Neural_RepairModeRequired(); 
    error Aoxc_Neural_ProtocolMismatch(bytes32 expected, bytes32 actual); 
    error Aoxc_Neural_SecurityVeto(address sentinel, uint256 risk);
    error Aoxc_Neural_BastionSealed(uint256 timestamp);
    error Aoxc_Neural_SignatureReused(bytes32 id);
    error Aoxc_Neural_IntegrityCheckFailed(); 
    error Aoxc_TemporalCollision();

    /*//////////////////////////////////////////////////////////////
                        4. FISCAL, VAULT & ASSETS
    //////////////////////////////////////////////////////////////*/
    error Aoxc_InsufficientBalance(uint256 available, uint256 required);
    error Aoxc_ExceedsDailyLimit(uint256 required, uint256 remaining);
    error Aoxc_ExceedsMaxTransfer(uint256 amount, uint256 max); 
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
    error Aoxc_UpgradeBlockedBySentinel();
    error Aoxc_NOT_SCHEDULED();

    /*//////////////////////////////////////////////////////////////
                        7. GOVERNANCE & NEURAL NEXUS
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Gov_QuorumNotMet(uint256 current, uint256 required);
    error Aoxc_Gov_ProposalNotActive(uint256 proposalId);
    error Aoxc_Gov_AlreadyVoted(address voter, uint256 proposalId);
    error Aoxc_Gov_VetoPeriodActive();
    error Aoxc_Gov_UnauthorizedProposer();
    error Aoxc_Gov_ActionDelayed();
    
    // FIX: AoxcAuditVoice Error (9582) Resolution
    error Aoxc_InvalidThreshold();

    /*//////////////////////////////////////////////////////////////
                        8. REGISTRY & REPUTATION (CORE)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Registry_UserAlreadyRegistered();
    error Aoxc_Registry_CitizenNotFound();
    error Aoxc_Registry_ReputationTooLow(uint256 current, uint256 minimum);
    error Aoxc_Registry_IdentityExpired();

    /*//////////////////////////////////////////////////////////////
                        9. TEMPORAL SECURITY (CLOCK)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_TemporalBreach(uint256 current, uint256 expected);
    error Aoxc_Neural_RiskThresholdBreached(uint256 score, uint256 threshold);

    /*//////////////////////////////////////////////////////////////
                        10. BRIDGE & ORACLE (FUTURE)
    //////////////////////////////////////////////////////////////*/
    error Aoxc_Bridge_InvalidSourceChain(uint256 chainId);
    error Aoxc_Bridge_MessageAlreadyProcessed(bytes32 msgHash);
    error Aoxc_Bridge_SyncOutdated();
    error Aoxc_Oracle_DataNotFound();
    error Aoxc_Oracle_ConsensusFailed();
}
