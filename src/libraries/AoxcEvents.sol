// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcEvents
 * @author Aoxcore Security Architecture
 * @notice Canonical event registry for the AoxcAN Akdeniz (v2.0.0) ecosystem.
 * @dev V2.1: Fixed "Max 3 Indexed" rule for Solidity 0.8.33 compatibility.
 */
library AoxcEvents {
    /*//////////////////////////////////////////////////////////////
                        1. NEURAL HANDSHAKE TELEMETRY
    //////////////////////////////////////////////////////////////*/

    event NeuralValidationSucceeded(
        bytes32 indexed packetHash, address indexed origin, uint16 indexed reasonCode, uint8 riskScore
    );
    event NeuralValidationFailed(
        bytes32 indexed packetHash, address indexed offender, string failureReason, uint8 riskScore
    );
    event NeuralRiskEscalated(bytes32 indexed operationId, address indexed trigger, uint8 oldRisk, uint8 newRisk);
    event NeuralSignalProcessed(string indexed signalType, bytes payload);

    /*//////////////////////////////////////////////////////////////
                        2. BRIDGE & GATEWAY (V2-X)
    //////////////////////////////////////////////////////////////*/

    event ChainSupportUpdated(uint16 indexed chainId, bool supported);
    // FIX: 3 indexed parametreye düşürüldü
    event CrossChainTransferFailed(
        uint16 indexed dstChainId, address indexed user, bytes32 indexed txId, uint256 amount, string reason
    );
    // FIX: 3 indexed parametreye düşürüldü
    event MigrationInFinalized(
        uint16 indexed srcChainId, address indexed to, bytes32 indexed migrationId, uint256 amount, uint256 nonce
    );
    // FIX: 3 indexed parametreye düşürüldü
    event MigrationInitiated(
        uint16 indexed dstChainId,
        address indexed from,
        bytes32 indexed migrationId,
        address to,
        uint256 amount,
        uint8 riskScore
    );
    event QuantumLimitsUpdated(uint256 minQuantum, uint256 maxQuantum);

    /*//////////////////////////////////////////////////////////////
                        3. CELLULAR & REGISTRY (IDENTITY)
    //////////////////////////////////////////////////////////////*/

    event CellSpawned(uint256 indexed cellId, bytes32 indexed cellHash, bytes32 prevHash);
    event MemberOnboarded(address indexed member, uint256 indexed cellId, uint8 riskScore);
    event ReputationUpdated(address indexed user, uint16 indexed reasonCode, uint256 oldScore, uint256 newScore);

    /*//////////////////////////////////////////////////////////////
                        4. CORE ASSET OPERATIONS
    //////////////////////////////////////////////////////////////*/

    event BurnExecuted(address indexed from, uint256 amount);
    event MintExecuted(address indexed to, uint256 amount, uint256 annualTotal);
    event BlacklistUpdated(address indexed target, bool indexed status, string reason);
    event RestrictionUpdated(address indexed account, bool indexed status, string reason);

    /*//////////////////////////////////////////////////////////////
                        5. FISCAL, VAULT & LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(address indexed user, uint256 indexed positionId, uint256 amount, uint8 riskScore);
    event NeuralRecoveryExecuted(address indexed token, address indexed to, uint256 amount, bytes32 protocolHash);
    event VaultWithdrawal(address indexed token, address indexed to, uint256 indexed nonce, uint256 amount);
    event GlobalLockStateChanged(bool indexed isLocked, uint16 reasonCode, uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                        6. GOVERNANCE & NEXUS
    //////////////////////////////////////////////////////////////*/

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, uint8 riskScore);
    event ProposalExecuted(uint256 indexed proposalId, uint16 indexed reasonCode);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 weight, uint8 riskScore);
    event KarujanNeuralVeto(uint256 indexed proposalId, bytes32 indexed protocolHash, uint8 riskScore);

    /*//////////////////////////////////////////////////////////////
                        7. SYSTEM & REPAIR ENGINE
    //////////////////////////////////////////////////////////////*/

    event GlobalAutoRepairModeToggled(bool indexed status, uint16 indexed reasonCode, bytes32 protocolHash);
    event AutonomousRepairSucceeded(bytes32 indexed componentId, uint256 attemptNo);
    event PatchExecuted(bytes4 indexed selector, address indexed target, address indexed logic);
    event SystemRepairInitiated(bytes32 indexed componentId, address indexed targetRepair);
    event ComponentSynchronized(bytes32 indexed componentKey, address indexed syncAgent);
}
