// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcNexus
 * @author AOXCAN Security Division
 * @notice Sovereign Governance Layer with Neural Veto & AI-Vetted Voting.
 * @dev Optimized for OpenZeppelin 5.0+. Compatible with AoxcFactory V2.
 */

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {IAoxcNexus} from "aoxc-interfaces/IAoxcNexus.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

contract AoxcNexus is
    IAoxcNexus,
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;
    using Address for address;

    /*//////////////////////////////////////////////////////////////
                        INTERNAL STRUCTS (DNA)
    //////////////////////////////////////////////////////////////*/

    struct ProposalCore {
        address proposer;
        bool exists;
        bool executed;
        bool vetoed;
        uint64 startTime;
        uint64 endTime;
        uint64 snapshot;
        uint256 forVotes;
        uint256 againstVotes;
        uint8 aiRiskScore;
    }

    struct NexusStorage {
        address aoxcToken;
        uint256 votingPeriod;
        uint256 votingDelay;
        uint256 quorumNumerator;
        bytes32 domainSeparator;
        mapping(uint256 => ProposalCore) proposals;
        mapping(uint256 => mapping(address => bool)) hasVoted;
    }

    // keccak256(abi.encode(uint256(keccak256("aoxc.storage.Nexus")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant NEXUS_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00800;

    function _getStore() internal pure returns (NexusStorage storage $) {
        assembly { $.slot := NEXUS_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Updated to V2 to match Factory selector.
     */
    function initializeNexusV2(address admin, address auditVoice, address token) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.AUDIT_VOICE_ROLE, auditVoice);

        NexusStorage storage $ = _getStore();
        $.aoxcToken = token;
        $.votingPeriod = 3 days;
        $.votingDelay = 1 hours;
        $.quorumNumerator = AoxcConstants.GOVERNANCE_QUORUM_BPS;

        $.domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainid,address verifyingContract)"),
                keccak256("AoxcNexus"),
                keccak256("V2.0.0"),
                block.chainid,
                address(this)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PROPOSAL FLOW
    //////////////////////////////////////////////////////////////*/

    function propose(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata calldatas,
        string calldata description,
        IAoxcCore.NeuralPacket calldata packet
    ) external override returns (uint256 proposalId) {
        proposalId = uint256(keccak256(abi.encode(targets, values, calldatas, keccak256(bytes(description)))));
        NexusStorage storage $ = _getStore();

        if ($.proposals[proposalId].exists) revert AoxcErrors.Aoxc_CustomRevert("NEXUS: DUP_PROPOSAL");

        $.proposals[proposalId] = ProposalCore({
            proposer: msg.sender,
            exists: true,
            executed: false,
            vetoed: false,
            startTime: uint64(block.timestamp + $.votingDelay),
            endTime: uint64(block.timestamp + $.votingDelay + $.votingPeriod),
            snapshot: uint64(block.number),
            forVotes: 0,
            againstVotes: 0,
            aiRiskScore: packet.riskScore
        });

        emit AoxcEvents.ProposalCreated(proposalId, msg.sender, packet.riskScore);
    }

    function queue(
        uint256 proposalId,
        IAoxcCore.NeuralPacket calldata /* packet */
    ) external override {
        NexusStorage storage $ = _getStore();
        if (!$.proposals[proposalId].exists) revert AoxcErrors.Aoxc_CustomRevert("NEXUS: NOT_FOUND");
        
        uint256 eta = block.timestamp + AoxcConstants.REPAIR_TIMELOCK;
        emit AoxcEvents.ProposalQueued(proposalId, eta, AoxcConstants.REPAIR_TIMELOCK);
    }

    function execute(
        uint256 proposalId,
        IAoxcCore.NeuralPacket calldata /* packet */
    ) external payable override nonReentrant whenNotPaused {
        if (state(proposalId) != ProposalState.Succeeded) {
            revert AoxcErrors.Aoxc_CustomRevert("NEXUS: STATE_NOT_READY");
        }
        _getStore().proposals[proposalId].executed = true;
        
        emit AoxcEvents.ProposalExecuted(proposalId, 100);
    }

    /*//////////////////////////////////////////////////////////////
                            NEURAL VETO
    //////////////////////////////////////////////////////////////*/

    function processNeuralVeto(uint256 proposalId, IAoxcCore.NeuralPacket calldata packet)
        external
        override
        onlyRole(AoxcConstants.AUDIT_VOICE_ROLE)
    {
        NexusStorage storage $ = _getStore();
        if (!$.proposals[proposalId].exists) revert AoxcErrors.Aoxc_CustomRevert("NEXUS: NOT_FOUND");

        $.proposals[proposalId].vetoed = true;
        $.proposals[proposalId].aiRiskScore = packet.riskScore;

        // V2-X Event Sync: Uses both protocolHash and riskScore
        emit AoxcEvents.KarujanNeuralVeto(proposalId, packet.protocolHash, packet.riskScore);
    }

    /*//////////////////////////////////////////////////////////////
                            VOTING ENGINE
    //////////////////////////////////////////////////////////////*/

    function castVote(uint256 proposalId, uint8 support, IAoxcCore.NeuralPacket calldata packet)
        external override returns (uint256 weight)
    {
        return _executeVote(msg.sender, proposalId, support, packet.riskScore);
    }

    function castVoteBySig(uint256 proposalId, uint8 support, IAoxcCore.NeuralPacket calldata packet)
        external override returns (uint256 weight)
    {
        return _executeVote(msg.sender, proposalId, support, packet.riskScore);
    }

    function _executeVote(address voter, uint256 id, uint8 support, uint8 risk) internal returns (uint256 weight) {
        NexusStorage storage $ = _getStore();
        if (state(id) != ProposalState.Active) revert AoxcErrors.Aoxc_CustomRevert("NEXUS: INACTIVE");
        if ($.hasVoted[id][voter]) revert AoxcErrors.Aoxc_CustomRevert("NEXUS: ALREADY_VOTED");

        weight = IVotes($.aoxcToken).getPastVotes(voter, $.proposals[id].snapshot);
        if (weight == 0) revert AoxcErrors.Aoxc_CustomRevert("NEXUS: NO_WEIGHT");

        $.hasVoted[id][voter] = true;

        if (support == 1) $.proposals[id].forVotes += weight;
        else $.proposals[id].againstVotes += weight;

        emit AoxcEvents.VoteCast(voter, id, support, weight, risk);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function state(uint256 proposalId) public view override returns (ProposalState) {
        NexusStorage storage $ = _getStore();
        ProposalCore storage p = $.proposals[proposalId];

        if (!p.exists) return ProposalState.Canceled;
        if (p.vetoed) return ProposalState.NeuralVetoed;
        if (p.executed) return ProposalState.Executed;
        if (block.timestamp < p.startTime) return ProposalState.Pending;
        if (block.timestamp <= p.endTime) return ProposalState.Active;

        bool quorumMet = (p.forVotes + p.againstVotes) >= $.quorumNumerator;
        return (p.forVotes > p.againstVotes && quorumMet) ? ProposalState.Succeeded : ProposalState.Defeated;
    }

    function proposalSnapshot(uint256 id) external view override returns (uint256) { return _getStore().proposals[id].snapshot; }
    function proposalDeadline(uint256 id) external view override returns (uint256) { return _getStore().proposals[id].endTime; }
    function proposalProposer(uint256 id) external view override returns (address) { return _getStore().proposals[id].proposer; }
    function proposalRiskScore(uint256 id) external view override returns (uint8) { return _getStore().proposals[id].aiRiskScore; }
    function quorum(uint256) external view override returns (uint256) { return _getStore().quorumNumerator; }

    function getNexusLockState() external view override returns (bool isLocked, uint256 cooldownRemaining) {
        return (paused(), 0);
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    uint256[50] private __gap;
}
