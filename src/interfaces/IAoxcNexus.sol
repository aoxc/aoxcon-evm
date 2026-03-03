// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcNexus
 * @author AoxcAN AI Architect
 * @notice Master interface for the Aoxcore Governance Nexus (V3.0).
 * @dev Enforces 10-Point Neural Handshake on all strategic DAO decisions.
 */
interface IAoxcNexus {
    /**
     * @notice Proposal lifecycle states including Neural and Repair terminal states.
     */
    enum ProposalState {
        Pending, // 0
        Active, // 1
        Canceled, // 2
        Defeated, // 3
        Succeeded, // 4
        Queued, // 5
        Expired, // 6
        Executed, // 7
        NeuralVetoed, // 8 (AI Interception via Rule 10)
        RepairPending // 9 (Auto-Repair triggering via Rule 8)
    }

    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event ProposalCreated(uint256 indexed proposalId, address proposer, uint8 riskScore);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta, uint256 nonce);
    event ProposalExecuted(uint256 indexed proposalId, uint16 reasonCode);
    event VoteCast(address indexed voter, uint256 indexed proposalId, uint256 weight, uint8 riskScore);
    event KarujanNeuralVeto(uint256 indexed proposalId, uint8 riskScore, bytes32 protocolHash);

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE VIEWS
    //////////////////////////////////////////////////////////////*/

    function state(uint256 proposalId) external view returns (ProposalState);
    function proposalSnapshot(uint256 proposalId) external view returns (uint256);
    function proposalDeadline(uint256 proposalId) external view returns (uint256);
    function proposalProposer(uint256 proposalId) external view returns (address);
    function proposalRiskScore(uint256 proposalId) external view returns (uint8);
    function quorum(uint256 timepoint) external view returns (uint256);
    function getNexusLockState() external view returns (bool isLocked, uint256 cooldownRemaining);

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 6 & 7: Submits a new proposal with initial neural vetting.
     */
    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description,
        IAoxcCore.NeuralPacket calldata packet
    ) external returns (uint256 proposalId);

    /**
     * @notice Rule 4 & 5: Moves a successful proposal to the Timelock queue.
     */
    function queue(uint256 proposalId, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 10: Executes the queued proposal after the Timelock period.
     */
    function execute(uint256 proposalId, IAoxcCore.NeuralPacket calldata packet) external payable;

    /**
     * @notice Rule 7, 8 & 10: Intercepts a proposal via AI Sentinel proof.
     * @dev This is the 'Karujan' AI Defense Layer.
     */
    function processNeuralVeto(uint256 proposalId, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                            VOTING ENGINE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 7: Casts a vote weighted by reputation and AI risk analysis.
     */
    function castVote(uint256 proposalId, uint8 support, IAoxcCore.NeuralPacket calldata packet)
        external
        returns (uint256 weight);

    /**
     * @notice Rule 10: Casts a vote via cryptographic signature (EIP-712).
     */
    function castVoteBySig(uint256 proposalId, uint8 support, IAoxcCore.NeuralPacket calldata packet)
        external
        returns (uint256 weight);
}
