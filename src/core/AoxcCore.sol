// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {IAoxcSentinel} from "aoxc-interfaces/IAoxcSentinel.sol";
import {IAoxcAutoRepair} from "aoxc-interfaces/IAoxcAutoRepair.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ERC20BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {
    ERC20PausableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {
    ERC20PermitUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {
    ERC20VotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAoxcV1 {
    function mint(address to, uint256 amount) external;
    function addToBlacklist(address account, string calldata reason) external;
    function removeFromBlacklist(address account) external;
    function pause() external;
    function unpause() external;
}

contract AoxcCore is
    Initializable,
    IAoxcCore,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    AccessControlUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

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
        mapping(address => uint256) lastActionBlock;
        mapping(address => uint256) userNonces;
        mapping(bytes4 => bool) quarantinedSelectors;
    }

    bytes32 private constant CORE_STORAGE_SLOT = 0x27f884a8677c731e8093d6e5a4073f1d8595531d054d5d71c1815e98544e3d00;

    function _getStore() internal pure returns (CoreStorage storage $) {
        bytes32 slot = CORE_STORAGE_SLOT;
        assembly { $.slot := slot }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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
                        IAOXCCORE IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    function executeNeuralAction(NeuralPacket calldata packet) external override returns (bool) {
        CoreStorage storage $ = _getStore();
        if (packet.protocolHash != $.protocolHash) revert AoxcErrors.Aoxc_Neural_IntegrityCheckFailed();
        if (packet.nonce != $.userNonces[packet.origin]++) revert AoxcErrors.Aoxc_Unauthorized("NONCE", packet.origin);
        if ($.globalLock) revert AoxcErrors.Aoxc_GlobalLockActive();
        if (block.timestamp > packet.deadline) revert AoxcErrors.Aoxc_TemporalCollision();

        emit AoxcEvents.NeuralSignalProcessed("V3_ACTION_OK", abi.encode(packet.origin, packet.nonce));
        return true;
    }

    function triggerEmergencyRepair(bytes4 selector, address target, string calldata reason)
        external
        override
        onlyRole(AoxcConstants.REPAIR_ROLE)
    {
        _getStore().quarantinedSelectors[selector] = true;
        emit AoxcEvents.CoreLockStateChanged(true, block.timestamp);
    }

    function getAiStatus() external view override returns (bool isActive, uint256 currentNeuralThreshold) {
        CoreStorage storage $ = _getStore();
        return ($.aiFailSafeActive, AoxcConstants.NEURAL_RISK_CRITICAL);
    }

    function setRestrictionStatus(address account, bool status, string calldata reason)
        external
        override
        onlyRole(AoxcConstants.SENTINEL_ROLE)
    {
        CoreStorage storage $ = _getStore();
        $.blacklisted[account] = status;
        $.blacklistReason[account] = reason;
        if ($.v1TokenLegacy != address(0)) {
            if (status) IAoxcV1($.v1TokenLegacy).addToBlacklist(account, reason);
            else IAoxcV1($.v1TokenLegacy).removeFromBlacklist(account);
        }
        emit AoxcEvents.BlacklistUpdated(account, status, reason);
    }

    function isRestricted(address account) external view override returns (bool) {
        return _getStore().blacklisted[account];
    }

    function mint(address to, uint256 amount) external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _mint(to, amount);
        if (_getStore().v1TokenLegacy != address(0)) IAoxcV1(_getStore().v1TokenLegacy).mint(to, amount);
    }

    function burn(address from, uint256 amount) external override {
        if (msg.sender != from) _checkRole(AoxcConstants.GOVERNANCE_ROLE, msg.sender);
        _burn(from, amount);
    }

    function getReputationMatrix(address account) external view override returns (uint256) {
        return _getStore().blacklisted[account] ? 0 : 100;
    }

    /*//////////////////////////////////////////////////////////////
                             CORE OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function totalSupply() public view override(ERC20Upgradeable, IAoxcCore) returns (uint256) {
        return super.totalSupply();
    }

    function balanceOf(address account) public view override(ERC20Upgradeable, IAoxcCore) returns (uint256) {
        return super.balanceOf(account);
    }

    function clock() public view override(IAoxcCore, ERC20VotesUpgradeable) returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public view override(IAoxcCore, ERC20VotesUpgradeable) returns (string memory) {
        return "mode=timestamp";
    }

    function getVotes(address account) public view override(IAoxcCore, ERC20VotesUpgradeable) returns (uint256) {
        return super.getVotes(account);
    }

    function delegates(address account) public view override(IAoxcCore, ERC20VotesUpgradeable) returns (address) {
        return super.delegates(account);
    }

    function delegate(address delegatee) public override(IAoxcCore, ERC20VotesUpgradeable) {
        super.delegate(delegatee);
    }

    function isCoreLocked() external view override returns (bool) {
        return _getStore().globalLock;
    }

    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }

    function _update(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20VotesUpgradeable)
    {
        CoreStorage storage $ = _getStore();
        if ($.globalLock && !hasRole(DEFAULT_ADMIN_ROLE, from)) revert AoxcErrors.Aoxc_GlobalLockActive();
        if (from != address(0) && $.blacklisted[from]) {
            revert AoxcErrors.Aoxc_Blacklisted(from, $.blacklistReason[from]);
        }
        super._update(from, to, amount);
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}
}
