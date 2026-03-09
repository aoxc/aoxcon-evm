// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcDaoManager (Neural V2.2.1)
 * @author AOXCAN Governance Division
 * @notice Hardened DAO Layer with Ghost Proposal Protection and EIP-712 Signatures.
 * @dev Implements Rule 9 (Unified Governance) and Rule 10 (Anti-Flashloan Stake Locking).
 * Optimized for OpenZeppelin 5.5.0 and Slither Security Scans.
 */

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

interface IAoxcRegistry {
    struct CitizenRecord {
        uint256 citizenId;
        uint256 joinedAt;
        uint256 tier;
        uint256 reputation;
        uint256 lastPulse;
        uint256 totalVoted;
        bool isBlacklisted;
    }
    function getCitizenInfo(address member) external view returns (CitizenRecord memory);
    function syncMemberTier(address member, uint256 stakedAmount) external;
}

contract AoxcDaoManager is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant CONFIRM_TYPEHASH = keccak256("Confirm(uint256 txIndex,uint256 nonce,uint256 deadline)");

    IAoxcRegistry public immutable REGISTRY;
    IERC20 public immutable AOXC_TOKEN;
    bytes32 public immutable DOMAIN_SEPARATOR;

    uint256 public constant MIN_TIER_REQUIRED = 2;

    /*//////////////////////////////////////////////////////////////
                             DAO STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public proposalLifespan;
    uint256 public nextTxIndex;
    uint256 public minExecutionPower;

    struct Transaction {
        address to;
        uint256 value;
        uint256 totalPowerConfirmed;
        uint256 createdAt;
        bool exists; // @dev: Ghost Proposal Protection
        bool executed;
        bytes data;
        mapping(address => bool) isConfirmed;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastVoteTxIndex;
    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address registry_, address token_, uint256 lifespan_) {
        if (registry_ == address(0) || token_ == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        REGISTRY = IAoxcRegistry(registry_);
        AOXC_TOKEN = IERC20(token_);
        proposalLifespan = lifespan_;
        minExecutionPower = 10_000 * 1e18;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainid,address verifyingContract)"),
                keccak256(bytes("Aoxc_DAO")),
                keccak256(bytes("2.2.1")),
                block.chainid,
                address(this)
            )
        );

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GOVERNANCE_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           STAKING & EXIT LOCK
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes AOXC tokens to gain voting power and sync Citizen Tier.
     */
    function joinAndStake(uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert AoxcErrors.Aoxc_CustomRevert("DAO: ZERO_VALUE");

        stakedBalances[msg.sender] += amount;
        AOXC_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        REGISTRY.syncMemberTier(msg.sender, stakedBalances[msg.sender]);

        emit AoxcEvents.ComponentSynchronized(keccak256("DAO_MEMBER_STAKE"), msg.sender);
    }

    /**
     * @notice Withdraws staked tokens.
     * @dev SECURITY: Prevents withdrawal if the user has an active vote on an unexpired proposal.
     */
    function exitStake(uint256 amount) external nonReentrant {
        uint256 balance = stakedBalances[msg.sender];
        if (balance < amount) revert AoxcErrors.Aoxc_CustomRevert("DAO: LOW_BALANCE");

        // Governance Lock Check
        uint256 lastIdx = lastVoteTxIndex[msg.sender];
        Transaction storage lastTx = transactions[lastIdx];
        if (lastTx.exists && !lastTx.executed) {
            if (block.timestamp < lastTx.createdAt + proposalLifespan) {
                revert AoxcErrors.Aoxc_CustomRevert("DAO: STAKE_LOCKED_ACTIVE_VOTE");
            }
        }

        stakedBalances[msg.sender] = balance - amount;
        REGISTRY.syncMemberTier(msg.sender, stakedBalances[msg.sender]);
        AOXC_TOKEN.safeTransfer(msg.sender, amount);

        emit AoxcEvents.ComponentSynchronized(keccak256("DAO_MEMBER_EXIT"), msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                         EIP-712 GOVERNANCE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Casts a vote using an EIP-712 signature.
     * @param txIndex The index of the proposal.
     * @param deadline Signature expiry timestamp.
     * @param signature The ECDSA signature.
     */
    function voteWithSignature(uint256 txIndex, uint256 deadline, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        if (block.timestamp > deadline) revert AoxcErrors.Aoxc_CustomRevert("GOV: SIG_EXPIRED");

        Transaction storage txn = transactions[txIndex];
        if (!txn.exists) revert AoxcErrors.Aoxc_CustomRevert("GOV: NOT_FOUND");
        if (txn.executed) revert AoxcErrors.Aoxc_CustomRevert("GOV: EXECUTED");
        if (block.timestamp > txn.createdAt + proposalLifespan) revert AoxcErrors.Aoxc_CustomRevert("GOV: EXPIRED");

        // EIP-712 Identity Recovery
        bytes32 structHash = keccak256(abi.encode(CONFIRM_TYPEHASH, txIndex, nonces[msg.sender], deadline));
        bytes32 hash = MessageHashUtils.toTypedDataHash(DOMAIN_SEPARATOR, structHash);
        address signer = ECDSA.recover(hash, signature);

        if (signer != msg.sender) revert AoxcErrors.Aoxc_CustomRevert("GOV: IDENTITY_MISMATCH");
        if (txn.isConfirmed[signer]) revert AoxcErrors.Aoxc_CustomRevert("GOV: DUPLICATE_VOTE");

        // Tier & Reputation Verification
        IAoxcRegistry.CitizenRecord memory citizen = REGISTRY.getCitizenInfo(signer);
        if (citizen.tier < MIN_TIER_REQUIRED || citizen.isBlacklisted) {
            revert AoxcErrors.Aoxc_Unauthorized("DAO_MEMBER", signer);
        }

        nonces[signer]++;
        // Voting Power Calculation: (Stake * Tier) + (Reputation Scale)
        uint256 power = (stakedBalances[signer] * citizen.tier) + (citizen.reputation * 1e18);
        if (power == 0) revert AoxcErrors.Aoxc_CustomRevert("GOV: ZERO_POWER");

        txn.isConfirmed[signer] = true;
        txn.totalPowerConfirmed += power;
        lastVoteTxIndex[signer] = txIndex;

        // Auto-Execution Check
        if (txn.totalPowerConfirmed >= minExecutionPower) {
            _executeDecision(txIndex);
        }
    }

    function _executeDecision(uint256 txIndex) internal {
        Transaction storage txn = transactions[txIndex];
        txn.executed = true;

        (bool success,) = txn.to.call{value: txn.value}(txn.data);
        if (!success) revert AoxcErrors.Aoxc_CustomRevert("GOV: EXECUTION_FAILED");

        emit AoxcEvents.ComponentSynchronized(keccak256("GOV_ACTION_EXECUTED"), txn.to);
    }

    function proposeAction(address to, uint256 value, bytes calldata data) external returns (uint256) {
        if (to == address(0) || to == address(this)) revert AoxcErrors.Aoxc_InvalidAddress();

        uint256 txIndex = nextTxIndex++;
        Transaction storage txn = transactions[txIndex];
        txn.to = to;
        txn.value = value;
        txn.data = data;
        txn.exists = true; // Prevents hayalet teklif (ghost proposal)
        txn.createdAt = block.timestamp;

        return txIndex;
    }

    receive() external payable {}
}
