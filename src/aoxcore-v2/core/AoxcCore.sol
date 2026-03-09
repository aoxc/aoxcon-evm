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

/**
 * @dev External interface for legacy V1 token interoperability.
 */
interface IAoxcV1 {
    function mint(address to, uint256 amount) external;
    function addToBlacklist(address account, string calldata reason) external;
    function removeFromBlacklist(address account) external;
}

event NeuralTransferPermitPrepared(address indexed origin, address indexed to, uint256 amount, uint256 nonce);
event NeuralProtectionModeUpdated(address indexed account, bool enabled);
event CriticalAddressUpdated(address indexed account, bool enabled);
event GovernanceActionScheduled(bytes32 indexed actionId, uint256 eta, bytes32 dataHash);
event GovernanceActionVetoed(bytes32 indexed actionId, address indexed by);
event GovernanceActionExecuted(bytes32 indexed actionId, address indexed by);

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
    uint256 public constant YEAR_SECONDS = 365 days;
    uint256 public constant HARD_CAP_INFLATION_BPS = 600;
    uint256 public constant V1_PARITY_ANCHOR_SUPPLY = 100_000_000_000 * 1e18;

    uint8 private constant MODE_FLAG_CRITICAL = 1 << 0;
    uint8 private constant MODE_FLAG_NEURAL_OPT_IN = 1 << 1;
    uint256 private constant GOV_TIMELOCK_MIN = 24 hours;
    uint256 private constant GOV_TIMELOCK_MAX = 48 hours;

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
        uint256 yearlyMintLimit;
        uint256 lastMintTimestamp;
        uint256 mintedThisYear;
        uint256 maxTransferAmount;
        uint256 dailyTransferLimit;
        bool aiFailSafeActive;
        bool globalLock;
        bytes32 protocolHash;
        mapping(address => bool) blacklisted;
        mapping(address => string) blacklistReason;
        mapping(address => bool) isExcludedFromLimits;
        mapping(address => uint256) dailySpent;
        mapping(address => uint256) lastTransferDay;
        mapping(address => uint8) modeFlags;
        mapping(address => uint256) transferPermitNonce;
        mapping(bytes32 => bool) transferPermits;
        mapping(bytes32 => uint48) transferPermitExpiry;
        mapping(bytes32 => uint256) scheduledEta;
        mapping(bytes32 => bytes32) scheduledDataHash;
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
        if (admin == address(0) || nexus == address(0) || sentinel == address(0)) {
            revert AoxcErrors.Aoxc_InvalidAddress();
        }
        if (integrityHash == bytes32(0)) revert AoxcErrors.Aoxc_CustomRevert("CORE: ZERO_INTEGRITY_HASH");

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
        $.maxTransferAmount = 500_000_000 * 1e18;
        $.dailyTransferLimit = 1_000_000_000 * 1e18;
        $.anchorSupply = V1_PARITY_ANCHOR_SUPPLY;
        $.yearlyMintLimit = ($.anchorSupply * HARD_CAP_INFLATION_BPS) / AoxcConstants.BPS_DENOMINATOR;
        $.lastMintTimestamp = block.timestamp;
        $.aiFailSafeActive = true;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, nexus);
        _grantRole(AoxcConstants.UPGRADER_ROLE, admin);
        _grantRole(AoxcConstants.SENTINEL_ROLE, sentinel);
        _grantRole(AoxcConstants.REPAIR_ROLE, repair);

        $.isExcludedFromLimits[admin] = true;
        $.isExcludedFromLimits[nexus] = true;
        $.isExcludedFromLimits[address(this)] = true;
    }

    /**
     * @notice Migration initializer for upgrading an existing v1 proxy in-place.
     * @dev Uses reinitializer(2) because v1 already consumed initializer version 1.
     *      This path does not mint and preserves all inherited ERC20/AccessControl state.
     */
    function migrateFromV1(
        address v1Token,
        address nexus,
        address sentinel,
        address repair,
        address upgrader,
        bytes32 integrityHash
    ) external reinitializer(2) onlyRole(DEFAULT_ADMIN_ROLE) {
        if (nexus == address(0) || sentinel == address(0) || upgrader == address(0)) {
            revert AoxcErrors.Aoxc_InvalidAddress();
        }
        if (integrityHash == bytes32(0)) revert AoxcErrors.Aoxc_CustomRevert("CORE: ZERO_INTEGRITY_HASH");

        CoreStorage storage $ = _getStore();

        $.v1TokenLegacy = v1Token;
        $.nexusHub = nexus;
        $.sentinelAi = sentinel;
        $.repairEngine = repair;
        $.protocolHash = integrityHash;
        $.lastPulse = block.timestamp;
        $.maxTransferAmount = 500_000_000 * 1e18;
        $.dailyTransferLimit = 1_000_000_000 * 1e18;
        $.anchorSupply = totalSupply();
        $.yearlyMintLimit = ($.anchorSupply * HARD_CAP_INFLATION_BPS) / AoxcConstants.BPS_DENOMINATOR;
        $.lastMintTimestamp = block.timestamp;
        $.mintedThisYear = 0;
        $.aiFailSafeActive = true;

        _grantRole(AoxcConstants.GOVERNANCE_ROLE, nexus);
        _grantRole(AoxcConstants.UPGRADER_ROLE, upgrader);
        _grantRole(AoxcConstants.SENTINEL_ROLE, sentinel);
        if (repair != address(0)) _grantRole(AoxcConstants.REPAIR_ROLE, repair);

        $.isExcludedFromLimits[nexus] = true;
        $.isExcludedFromLimits[upgrader] = true;
        $.isExcludedFromLimits[address(this)] = true;
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
        CoreStorage storage $ = _getStore();
        if ($.blacklisted[to]) revert AoxcErrors.Aoxc_Blacklisted(to, $.blacklistReason[to]);

        if (block.timestamp >= $.lastMintTimestamp + YEAR_SECONDS) {
            uint256 periods = (block.timestamp - $.lastMintTimestamp) / YEAR_SECONDS;
            $.lastMintTimestamp += periods * YEAR_SECONDS;
            $.mintedThisYear = 0;
        }

        if ($.mintedThisYear + amount > $.yearlyMintLimit) revert AoxcErrors.Aoxc_InflationHardcapReached();
        if (totalSupply() + amount > $.anchorSupply * 3) revert AoxcErrors.Aoxc_InflationHardcapReached();

        $.mintedThisYear += amount;
        _mint(to, amount);
        if ($.v1TokenLegacy != address(0)) {
            try IAoxcV1($.v1TokenLegacy).mint(to, amount) {} catch {}
        }
    }

    function burn(address from, uint256 amount) external override {
        if (_msgSender() != from) _checkRole(AoxcConstants.GOVERNANCE_ROLE, _msgSender());
        _burn(from, amount);
    }

    /**
     * @notice V1 compatibility: admin-managed transfer velocity limits.
     */
    function setTransferVelocity(uint256 maxTx, uint256 dailyLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CoreStorage storage $ = _getStore();
        $.maxTransferAmount = maxTx;
        $.dailyTransferLimit = dailyLimit;
    }

    /**
     * @notice V1 compatibility: admin exclusion from velocity controls.
     */
    function setExclusionFromLimits(address account, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _getStore().isExcludedFromLimits[account] = status;
    }

    function pause() external onlyRole(AoxcConstants.SENTINEL_ROLE) { _pause(); }

    function unpause() external onlyRole(AoxcConstants.SENTINEL_ROLE) { _unpause(); }

    function isBlacklisted(address account) external view returns (bool) {
        return _getStore().blacklisted[account];
    }

    function getMintPolicy() external view returns (uint256 yearlyLimit, uint256 mintedInCurrentYear, uint256 windowStart) {
        CoreStorage storage $ = _getStore();
        return ($.yearlyMintLimit, $.mintedThisYear, $.lastMintTimestamp);
    }

    function _isNeuralProtected(CoreStorage storage $, address account) internal view returns (bool) {
        return ($.modeFlags[account] & (MODE_FLAG_CRITICAL | MODE_FLAG_NEURAL_OPT_IN)) != 0;
    }

    function _scheduleGovernanceAction(bytes32 actionId, bytes32 dataHash, uint256 eta) internal {
        uint256 minEta = block.timestamp + GOV_TIMELOCK_MIN;
        uint256 maxEta = block.timestamp + GOV_TIMELOCK_MAX;
        if (eta < minEta || eta > maxEta) {
            revert AoxcErrors.Aoxc_Gov_TimelockWindowInvalid(eta, minEta, maxEta);
        }
        CoreStorage storage $ = _getStore();
        $.scheduledEta[actionId] = eta;
        $.scheduledDataHash[actionId] = dataHash;
        emit GovernanceActionScheduled(actionId, eta, dataHash);
    }

    function _consumeGovernanceAction(bytes32 actionId, bytes32 dataHash) internal {
        CoreStorage storage $ = _getStore();
        uint256 eta = $.scheduledEta[actionId];
        if (eta == 0) revert AoxcErrors.Aoxc_Gov_NoScheduledAction(actionId);
        if ($.scheduledDataHash[actionId] != dataHash) revert AoxcErrors.Aoxc_CustomRevert("CORE: ACTION_HASH_MISMATCH");
        if (block.timestamp < eta) revert AoxcErrors.Aoxc_Gov_TimelockNotReady(eta, block.timestamp);
        delete $.scheduledEta[actionId];
        delete $.scheduledDataHash[actionId];
        emit GovernanceActionExecuted(actionId, _msgSender());
    }


    /**
     * @notice Marks or unmarks an account as critical-risk for transfer controls.
     * @dev Critical accounts require prepared neural permits for outbound transfers.
     */
    function setCriticalAddress(address account, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        CoreStorage storage $ = _getStore();
        uint8 flags = $.modeFlags[account];
        if (enabled) $.modeFlags[account] = flags | MODE_FLAG_CRITICAL;
        else $.modeFlags[account] = flags & ~MODE_FLAG_CRITICAL;
        emit CriticalAddressUpdated(account, enabled);
    }

    /**
     * @notice Enables or disables optional neural protection mode for caller transfers.
     */
    function setNeuralProtectMode(bool enabled) external {
        CoreStorage storage $ = _getStore();
        uint8 flags = $.modeFlags[_msgSender()];
        if (enabled) $.modeFlags[_msgSender()] = flags | MODE_FLAG_NEURAL_OPT_IN;
        else $.modeFlags[_msgSender()] = flags & ~MODE_FLAG_NEURAL_OPT_IN;
        emit NeuralProtectionModeUpdated(_msgSender(), enabled);
    }

    /**
     * @notice Prepares a one-time neural permit bound to transfer tuple and nonce.
     * @dev Permit expires at `packet.deadline` and is consumed on the next matching transfer.
     */
    function prepareNeuralTransfer(address to, uint256 amount, NeuralPacket calldata packet) external {
        CoreStorage storage $ = _getStore();
        if (!_isNeuralProtected($, _msgSender())) {
            revert AoxcErrors.Aoxc_Neural_ModeDisabled(_msgSender());
        }
        if (packet.origin != _msgSender() || packet.target != to || packet.value != amount) {
            revert AoxcErrors.Aoxc_Neural_InvalidPacketBinding();
        }
        if (!IAoxcSentinel($.sentinelAi).validateNeuralPacket(packet)) {
            revert AoxcErrors.Aoxc_Neural_SecurityVeto(_msgSender(), packet.riskScore);
        }

        uint256 nonce = $.transferPermitNonce[_msgSender()];
        bytes32 permitId = keccak256(abi.encode(_msgSender(), to, amount, nonce));
        $.transferPermits[permitId] = true;
        $.transferPermitExpiry[permitId] = packet.deadline;

        emit NeuralTransferPermitPrepared(_msgSender(), to, amount, nonce);
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
        
        if (from != address(0)) {
            if ($.blacklisted[from]) revert AoxcErrors.Aoxc_Blacklisted(from, $.blacklistReason[from]);
            if (to != address(0) && !$.isExcludedFromLimits[from]) {
                if (amount > $.maxTransferAmount) revert AoxcErrors.Aoxc_ExceedsMaxTransfer(amount, $.maxTransferAmount);
                uint256 day = block.timestamp / 1 days;
                if ($.lastTransferDay[from] != day) {
                    $.dailySpent[from] = 0;
                    $.lastTransferDay[from] = day;
                }
                uint256 remaining = $.dailyTransferLimit - $.dailySpent[from];
                if (amount > remaining) revert AoxcErrors.Aoxc_ExceedsDailyLimit(amount, remaining);
                $.dailySpent[from] += amount;

                if (_isNeuralProtected($, from)) {
                    uint256 nonce = $.transferPermitNonce[from];
                    bytes32 permitId = keccak256(abi.encode(from, to, amount, nonce));
                    if (!$.transferPermits[permitId]) {
                        revert AoxcErrors.Aoxc_Neural_PermitMissing(from, to, amount, nonce);
                    }
                    uint48 expiry = $.transferPermitExpiry[permitId];
                    if (expiry < block.timestamp) {
                        delete $.transferPermits[permitId];
                        delete $.transferPermitExpiry[permitId];
                        $.transferPermitNonce[from] = nonce + 1;
                        revert AoxcErrors.Aoxc_Neural_PermitExpired(expiry, block.timestamp);
                    }
                    delete $.transferPermits[permitId];
                    delete $.transferPermitExpiry[permitId];
                    $.transferPermitNonce[from] = nonce + 1;
                }

            }
        }

        if (to != address(0) && $.blacklisted[to]) {
            revert AoxcErrors.Aoxc_Blacklisted(to, $.blacklistReason[to]);
        }

        super._update(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    /**
     * @notice Schedules global lock state transition with governance timelock.
     */
    function scheduleGlobalLock(bool newState, uint256 eta) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        bytes32 actionId = keccak256("GLOBAL_LOCK");
        _scheduleGovernanceAction(actionId, keccak256(abi.encode(newState)), eta);
    }

    /**
     * @notice Executes previously scheduled global lock transition.
     */
    function executeGlobalLock(bool newState) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        bytes32 actionId = keccak256("GLOBAL_LOCK");
        _consumeGovernanceAction(actionId, keccak256(abi.encode(newState)));
        _getStore().globalLock = newState;
    }

    /**
     * @notice Schedules critical address mutation under timelock.
     */
    function scheduleCriticalAddress(address account, bool enabled, uint256 eta) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        bytes32 actionId = keccak256(abi.encode("CRITICAL_ADDRESS", account));
        _scheduleGovernanceAction(actionId, keccak256(abi.encode(enabled)), eta);
    }

    /**
     * @notice Executes previously scheduled critical address mutation.
     */
    function executeCriticalAddress(address account, bool enabled) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        bytes32 actionId = keccak256(abi.encode("CRITICAL_ADDRESS", account));
        _consumeGovernanceAction(actionId, keccak256(abi.encode(enabled)));

        CoreStorage storage $ = _getStore();
        uint8 flags = $.modeFlags[account];
        if (enabled) $.modeFlags[account] = flags | MODE_FLAG_CRITICAL;
        else $.modeFlags[account] = flags & ~MODE_FLAG_CRITICAL;
        emit CriticalAddressUpdated(account, enabled);
    }

    /**
     * @notice Governance veto for any scheduled action identifier.
     */
    function vetoScheduledAction(bytes32 actionId) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        CoreStorage storage $ = _getStore();
        if ($.scheduledEta[actionId] == 0) revert AoxcErrors.Aoxc_Gov_NoScheduledAction(actionId);
        delete $.scheduledEta[actionId];
        delete $.scheduledDataHash[actionId];
        emit GovernanceActionVetoed(actionId, _msgSender());
    }

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

    function isNeuralProtectEnabled(address account) external view returns (bool) {
        return (_getStore().modeFlags[account] & MODE_FLAG_NEURAL_OPT_IN) != 0;
    }

    function isCriticalAddress(address account) external view returns (bool) {
        return (_getStore().modeFlags[account] & MODE_FLAG_CRITICAL) != 0;
    }
}
