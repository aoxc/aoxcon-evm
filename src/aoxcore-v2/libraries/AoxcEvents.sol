// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcEvents
 * @author Aoxcore Security Architecture
 * @notice Canonical event registry for the AoxcAN Akdeniz (v2.0.0) ecosystem.
 * @dev V2.0: Optimized for Factory Deployment, Neural Nexus, and Autonomous Repair sync.
 * Enforces "Max 3 Indexed" rule for Solidity 0.8.33 compatibility.
 */
library AoxcEvents {
    /*//////////////////////////////////////////////////////////////
                        1. INFRASTRUCTURE & FACTORY (BUILD)
    //////////////////////////////////////////////////////////////*/

    // Asset Production Telemetry
    event AssetBuilt(address indexed to, uint256 indexed assetId, uint8 aType, uint8 riskScore);
    
    event CellSpawned(uint256 indexed cellId, bytes32 indexed cellHash, bytes32 prevHash);
    event MemberOnboarded(address indexed member, uint256 indexed cellId, uint8 riskScore);

    /*//////////////////////////////////////////////////////////////
                        2. NEURAL HANDSHAKE TELEMETRY
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
                        3. BRIDGE & GATEWAY (V3-X)
    //////////////////////////////////////////////////////////////*/

    event ChainSupportUpdated(uint16 indexed chainId, bool supported);
    event CrossChainTransferFailed(
        uint16 indexed dstChainId, address indexed user, bytes32 indexed txId, uint256 amount, string reason
    );
    event MigrationInFinalized(
        uint16 indexed srcChainId, address indexed to, bytes32 indexed migrationId, uint256 amount, uint256 nonce
    );
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
                        4. CELLULAR & REGISTRY (IDENTITY)
    //////////////////////////////////////////////////////////////*/

    event ReputationUpdated(address indexed user, uint256 oldScore, uint256 newScore, uint16 reasonCode);
    event BurnExecuted(address indexed from, uint256 amount);
    event MintExecuted(address indexed to, uint256 amount, uint256 annualTotal);
    event BlacklistUpdated(address indexed target, bool indexed status, string reason);
    event RestrictionUpdated(address indexed account, bool indexed status, string reason);

    /*//////////////////////////////////////////////////////////////
                        5. CPEX & FINANCIAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(address indexed user, uint256 indexed positionId, uint256 amount, uint8 riskScore);
    event PositionClosed(address indexed user, uint256 totalReturned, uint256 penalty, uint256 indexed nonce);
    event SwapExecuted(
        address indexed user, 
        address indexed tokenIn, 
        address indexed tokenOut, 
        uint256 amountIn, 
        uint256 amountOut
    );
    event DrawerSynchronized(address indexed asset, uint256 currentStock);
    event AutonomousCorrectionFailed(bytes32 indexed componentId, string reason, uint256 timestamp);
    event LiquidityAdded(address indexed provider, uint256 amountToken, uint256 amountNative);

    /*//////////////////////////////////////////////////////////////
                        6. TREASURY & VAULT (SOVEREIGN)
    //////////////////////////////////////////////////////////////*/

    event VaultFunded(address indexed sender, uint256 amount);
    event VaultWithdrawal(address indexed token, address indexed to, uint256 indexed nonce, uint256 amount);
    event NeuralRecoveryExecuted(address indexed token, address indexed to, uint256 amount, bytes32 protocolHash);

    /*//////////////////////////////////////////////////////////////
                        7. GOVERNANCE, NEXUS & AUDITVOICE
    //////////////////////////////////////////////////////////////*/

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, uint8 riskScore);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta, uint256 delay);
    event ProposalExecuted(uint256 indexed proposalId, uint16 indexed reasonCode);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, uint256 weight, uint8 riskScore);
    event CommunityVetoSignaled(uint256 indexed proposalId, uint256 totalVetoPower);

    // CRITICAL FIX: Overloading for Nexus (3 args) and AuditVoice (2 args) compatibility
    event KarujanNeuralVeto(uint256 indexed proposalId, uint8 riskScore);
    event KarujanNeuralVeto(uint256 indexed proposalId, bytes32 indexed protocolHash, uint8 riskScore);

    /*//////////////////////////////////////////////////////////////
                        8. SYSTEM & REPAIR ENGINE
    //////////////////////////////////////////////////////////////*/

    event GlobalAutoRepairModeToggled(bool indexed status, uint16 indexed reasonCode, bytes32 protocolHash);
    event AutonomousRepairSucceeded(bytes32 indexed componentId, uint256 attemptNo);
    event PatchExecuted(bytes4 indexed selector, address indexed target, address indexed logic);
    event SystemRepairInitiated(bytes32 indexed componentId, address indexed targetRepair);
    event ComponentSynchronized(bytes32 indexed componentKey, address indexed syncAgent);
    event GlobalLockStateChanged(bool indexed isLocked, uint16 reasonCode, uint256 timestamp);
    
    /*//////////////////////////////////////////////////////////////
                        9. EXTRA TELEMETRY (ADD-ONS)
    //////////////////////////////////////////////////////////////*/
    event HeartbeatSynced(uint256 timestamp, uint256 nextExpectedPulse);
    event NeuralValidation(bytes32 indexed packetHash, uint8 riskScore, bool approved);
    event NeuralRiskEscalation(bytes32 indexed operationId, uint256 riskScore, uint256 newDelay);
    event UpgradeScheduled(address indexed target, uint256 readyAt);
}
