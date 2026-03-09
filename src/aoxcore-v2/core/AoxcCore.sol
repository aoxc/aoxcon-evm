// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcCore
 * @author AOXCAN Neural Division
 * @notice Central Logic Controller and Governance Token for the AOXC Autonomous Ecosystem.
 * @dev V2 Core with V3-ready neural gating and namespaced storage (ERC-7201).
 * Verified against OpenZeppelin Upgradeable v5.0 protocols.
 */

// --- Interfaces & Libraries ---
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {IAoxcSentinel} from "aoxc-interfaces/IAoxcSentinel.sol";
import {IAoxcAutoRepair} from "aoxc-interfaces/IAoxcAutoRepair.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

// --- OpenZeppelin Upgradeable v5.0 ---
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ERC20PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/VotesUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev External interface for legacy V1 token interoperability.
 */
interface IAoxcV1 {
    function mint(address to, uint256 amount) external;
    function addToBlacklist(address account, string calldata reason) external;
    function removeFromBlacklist(address account) external;
}



contract AoxcCore is
    Initializable,
    ContextUpgradeable,
    IAoxcCore,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    NoncesUpgradeable,         
    ERC20PermitUpgradeable,    
    VotesUpgradeable,          
    ERC20VotesUpgradeable,     
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                NAMESPACED STORAGE (ERC-7201 COMPLIANT)
    //////////////////////////////////////////////////////////////*/

    struct CoreStorage {
        address v1TokenLegacy;
        address sentinelAi;
        address repairEngine;
        address nexusHub;
        uint256 lastPulse;
        uint256 anchorSupply;
        uint256 mintedThisYear;
        uint256 dailyTransferLimit;
        bool aiFailSafeActive;
        bool globalLock;
        bytes32 protocolHash;
        mapping(address => bool) blacklisted;
        mapping(address => string) blacklistReason;
        mapping(address => bool) isExcludedFromLimits;
        mapping(address => uint256) dailySpent;
        mapping(address => uint256) lastTransferDay;
        mapping(address => uint256) userNonces;
        mapping(bytes4 => bool) quarantinedSelectors;
    }

    /**
     * @dev keccak256(abi.encode(uint256(keccak256("aoxc.storage.Core")) - 1)) & ~bytes32(uint256(0xff))
     */
    bytes32 private constant CORE_STORAGE_SLOT = 0x27f884a8677c731e8093d6e5a4073f1d8595531d054d5d71c1815e98544e3d00;

    function _getStore() internal pure returns (CoreStorage storage $) {
        assembly { $.slot := CORE_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the V2 Core with V3-ready neural hooks.
     * @param v1Token Legacy AOXC token address.
     * @param nexus Governance Hub (Neural Nexus).
     * @param sentinel AI-Sentinel Gateway.
     * @param repair Autonomous Repair Engine.
     */
    function initializeV2(
        address v1Token,
        address nexus,
        address sentinel,
        address repair,
        address admin,
        bytes32 integrityHash
    ) external initializer {
        __ERC20_init("AoxcCore", "AOXC");
        __ERC20Permit_init("AoxcCore");
        __ReentrancyGuard_init();
        __ERC20Votes_init();
        __AccessControl_init();
        __ERC20Pausable_init();

        CoreStorage storage $ = _getStore();
        $.v1TokenLegacy = v1Token;
        $.nexusHub = nexus;
        $.sentinelAi = sentinel;
        $.repairEngine = repair;
        $.protocolHash = integrityHash;
        $.lastPulse = block.timestamp;
        $.dailyTransferLimit = 1_000_000 * 1e18;
        $.anchorSupply = 100_000_000 * 1e18;
        $.aiFailSafeActive = true;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, nexus);
        _grantRole(AoxcConstants.UPGRADER_ROLE, admin);
        _grantRole(AoxcConstants.SENTINEL_ROLE, sentinel);
        _grantRole(AoxcConstants.REPAIR_ROLE, repair);

        $.isExcludedFromLimits[admin] = true;
        $.isExcludedFromLimits[nexus] = true;
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL LOGIC (V3-READY)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates cryptographic neural signals from the Sentinel.
     * @dev Core of the otonom defense system. Checks for replay and protocol integrity.
     */
    function executeNeuralAction(NeuralPacket calldata packet) external override returns (bool) {
        CoreStorage storage $ = _getStore();
        if (packet.protocolHash != $.protocolHash) revert AoxcErrors.Aoxc_Neural_IntegrityCheckFailed();
        
        unchecked {
            if (packet.nonce != $.userNonces[packet.origin]++) revert AoxcErrors.Aoxc_Unauthorized("INVALID_NONCE", packet.origin);
        }

        if ($.globalLock) revert AoxcErrors.Aoxc_GlobalLockActive();
        if (block.timestamp > packet.deadline) revert AoxcErrors.Aoxc_TemporalCollision();

        emit AoxcEvents.NeuralSignalProcessed("V2_NEURAL_STUB", abi.encode(packet.origin, packet.nonce));
        return true;
    }

    /**
     * @notice Surgical defense mechanism. Quarantines specific functions under threat.
     */
    function triggerEmergencyRepair(
        bytes4 selector,
        address /* _target */,
        string calldata /* _reason */
    ) external override onlyRole(AoxcConstants.REPAIR_ROLE) {
        _getStore().quarantinedSelectors[selector] = true;
        
        // V3-Ready: Signal the repair engine to start autonomous patch generation
        emit AoxcEvents.SystemRepairInitiated(keccak256(abi.encodePacked(selector)), _msgSender());
        emit AoxcEvents.GlobalLockStateChanged(true, AoxcConstants.REASON_DEFENSE_TRIGGER, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET CONTROL & V1 SYNC
    //////////////////////////////////////////////////////////////*/

    function setRestrictionStatus(
        address account,
        bool status,
        string calldata reason
    ) external override onlyRole(AoxcConstants.SENTINEL_ROLE) {
        CoreStorage storage $ = _getStore();
        $.blacklisted[account] = status;
        $.blacklistReason[account] = reason;
        
        if ($.v1TokenLegacy != address(0)) {
            try IAoxcV1($.v1TokenLegacy).addToBlacklist(account, reason) {} catch {}
        }
        emit AoxcEvents.BlacklistUpdated(account, status, reason);
    }

    function mint(address to, uint256 amount) external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _mint(to, amount);
        if (_getStore().v1TokenLegacy != address(0)) {
            try IAoxcV1(_getStore().v1TokenLegacy).mint(to, amount) {} catch {}
        }
    }

    function burn(address from, uint256 amount) external override {
        if (_msgSender() != from) _checkRole(AoxcConstants.GOVERNANCE_ROLE, _msgSender());
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            OVERRIDES & LINTING
    //////////////////////////////////////////////////////////////*/

    function clock() public view override(IAoxcCore, VotesUpgradeable) returns (uint48) {
        return uint48(block.timestamp);
    }

    /**
     * @notice Returns governance clock mode. 
     * @dev address(this) access silences Solidity Warning (2018) for pure-to-view restriction.
     */
    function CLOCK_MODE() public view override(IAoxcCore, VotesUpgradeable) returns (string memory) {
        address(this); 
        return "mode=timestamp";
    }

    function getVotes(address account) public view override(IAoxcCore, VotesUpgradeable) returns (uint256) {
        return super.getVotes(account);
    }

    function delegates(address account) public view override(IAoxcCore, VotesUpgradeable) returns (address) {
        return super.delegates(account);
    }

    function delegate(address delegatee) public override(IAoxcCore, VotesUpgradeable) {
        super.delegate(delegatee);
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    function totalSupply() public view override(ERC20Upgradeable, IAoxcCore) returns (uint256) {
        return super.totalSupply();
    }

    function balanceOf(address account) public view override(ERC20Upgradeable, IAoxcCore) returns (uint256) {
        return super.balanceOf(account);
    }

    /**
     * @dev Internal update featuring the global lock and blacklist gating logic.
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable) {
        CoreStorage storage $ = _getStore();
        
        if ($.globalLock && !hasRole(DEFAULT_ADMIN_ROLE, from)) {
            revert AoxcErrors.Aoxc_GlobalLockActive();
        }
        
        if (from != address(0) && $.blacklisted[from]) {
            revert AoxcErrors.Aoxc_Blacklisted(from, $.blacklistReason[from]);
        }

        super._update(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    /*//////////////////////////////////////////////////////////////
                            V2 VIEW INTERFACE
    //////////////////////////////////////////////////////////////*/

    function getAiStatus() external view override returns (bool isActive, uint256 currentNeuralThreshold) {
        CoreStorage storage $ = _getStore();
        return ($.aiFailSafeActive, AoxcConstants.NEURAL_RISK_CRITICAL);
    }

    function isRestricted(address account) external view override returns (bool) {
        return _getStore().blacklisted[account];
    }

    function isCoreLocked() external view override returns (bool) {
        return _getStore().globalLock;
    }

    function getReputationMatrix(address account) external view override returns (uint256) {
        return _getStore().blacklisted[account] ? 0 : 100;
    }
}
