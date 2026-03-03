// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcCpex (Neural V2.2)
 * @author AOXCAN Finance & AI Division
 * @notice Neural-boosted staking engine with milestone-based early exit penalties.
 * @dev Optimized for OpenZeppelin 5.0+ & Neural Boost Verification.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INTERNAL
import {IAoxcCpex} from "aoxc-interfaces/IAoxcCpex.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

contract AoxcCpex is IAoxcCpex, Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE (DNA)
    //////////////////////////////////////////////////////////////*/

    struct StakingStorage {
        uint256 totalValueLocked;
        uint256 baseYieldRateBps;
        uint256 attritionPenaltyBps;
        uint256 minLockdownDuration;
        mapping(address => IAoxcCpex.PositionInfo[]) accountPositions;
    }

    struct MainStorage {
        address neuralSentinelNode;
        address coreAssetToken;
        address treasury;
        uint256 operationalNonce;
        bool isSovereignVaultSealed;
    }

    // ERC-7201 Compliance Slots
    bytes32 private constant STAKING_STORAGE_SLOT = 0x1f5a1a117560126a10065a38a362244f7d3e0b29845ec26095f36e84d4367b00;
    bytes32 private constant MAIN_STORAGE_SLOT = 0x27f884a8677c731e8093d6e5a4073f1d8595531d054d5d71c1815e98544e3d00;

    function _getStakeStore() internal pure returns (StakingStorage storage $) {
        assembly { $.slot := STAKING_STORAGE_SLOT }
    }

    function _getMainStore() internal pure returns (MainStorage storage $) {
        assembly { $.slot := MAIN_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeCpexV2(address nexus, address aiNode, address token, address treasury) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        // __UUPSUpgradeable_init() removed for OZ v5 compatibility

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, nexus);

        MainStorage storage main = _getMainStore();
        StakingStorage storage stake = _getStakeStore();

        main.neuralSentinelNode = aiNode;
        main.coreAssetToken = token;
        main.treasury = treasury;

        stake.baseYieldRateBps = AoxcConstants.STAKING_REWARD_APR_BPS;
        stake.attritionPenaltyBps = 1000; // 10% Penalty
        stake.minLockdownDuration = 90 days;
    }

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function openPosition(uint256 amount, uint256 duration, uint64 boostFactor, bytes calldata aiProof)
        external
        nonReentrant
    {
        MainStorage storage main = _getMainStore();
        StakingStorage storage stake = _getStakeStore();

        if (main.isSovereignVaultSealed) revert AoxcErrors.Aoxc_GlobalLockActive();
        if (!_isValidDuration(duration)) revert AoxcErrors.Aoxc_CustomRevert("CPEX: INVALID_DURATION");

        _verifyNeuralProof(main, amount, duration, boostFactor, aiProof);

        stake.totalValueLocked += amount;
        stake.accountPositions[msg.sender].push(
            IAoxcCpex.PositionInfo({
                principal: uint128(amount),
                entryTime: uint64(block.timestamp),
                lockPeriod: uint64(duration),
                neuralBoost: boostFactor,
                isActive: true
            })
        );

        IERC20(main.coreAssetToken).safeTransferFrom(msg.sender, address(this), amount);

        emit AoxcEvents.PositionOpened(msg.sender, stake.accountPositions[msg.sender].length - 1, amount, duration);
    }

    function closePosition(uint256 index) external nonReentrant {
        StakingStorage storage stake = _getStakeStore();
        MainStorage storage main = _getMainStore();

        IAoxcCpex.PositionInfo[] storage positions = stake.accountPositions[msg.sender];
        if (index >= positions.length) revert AoxcErrors.Aoxc_StakeNotActive();

        IAoxcCpex.PositionInfo storage pos = positions[index];
        if (!pos.isActive) revert AoxcErrors.Aoxc_StakeNotActive();

        uint256 elapsedTime = block.timestamp - pos.entryTime;
        uint256 principalToReturn = uint256(pos.principal);
        uint256 penalty;
        bool isEarly = elapsedTime < pos.lockPeriod;

        if (isEarly) {
            penalty = (principalToReturn * stake.attritionPenaltyBps) / AoxcConstants.BPS_DENOMINATOR;
            principalToReturn -= penalty;
        }

        uint256 effectiveTime = isEarly ? _calculateMilestone(elapsedTime) : pos.lockPeriod;
        uint256 yield = (uint256(pos.principal) * effectiveTime * stake.baseYieldRateBps * uint256(pos.neuralBoost))
            / (365 days * AoxcConstants.BPS_DENOMINATOR * 10000);

        stake.totalValueLocked -= uint256(pos.principal);
        pos.isActive = false;

        IERC20(main.coreAssetToken).safeTransfer(msg.sender, principalToReturn + yield);
        if (penalty > 0 && main.treasury != address(0)) {
            IERC20(main.coreAssetToken).safeTransfer(main.treasury, penalty);
        }

        emit AoxcEvents.PositionClosed(msg.sender, principalToReturn, penalty, isEarly);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verifyNeuralProof(MainStorage storage main, uint256 a, uint256 d, uint64 b, bytes calldata s) internal {
        bytes32 mHash =
            keccak256(abi.encode(msg.sender, a, d, b, main.operationalNonce, address(this))).toEthSignedMessageHash();
        if (mHash.recover(s) != main.neuralSentinelNode) revert AoxcErrors.Aoxc_Neural_IdentityForgery();

        unchecked {
            main.operationalNonce++;
        }
    }

    function _calculateMilestone(uint256 e) internal pure returns (uint256) {
        if (e >= 270 days) return 270 days;
        if (e >= 180 days) return 180 days;
        if (e >= 90 days) return 90 days;
        return 0;
    }

    function _isValidDuration(uint256 d) internal pure returns (bool) {
        return (d == 90 days || d == 180 days || d == 270 days || d == 365 days);
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & SYSTEM
    //////////////////////////////////////////////////////////////*/

    function updateOperationalParams(uint256 newRate, uint256 newPenalty)
        external
        onlyRole(AoxcConstants.GOVERNANCE_ROLE)
    {
        StakingStorage storage stake = _getStakeStore();
        stake.baseYieldRateBps = newRate;
        stake.attritionPenaltyBps = newPenalty;
    }

    function setVaultSeal(bool status) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _getMainStore().isSovereignVaultSealed = status;
    }

    function _authorizeUpgrade(address) internal override {
        _checkRole(AoxcConstants.GOVERNANCE_ROLE);
    }

    /**
     * @dev Storage gap for future upgrades.
     */
    uint256[50] private __gap;
}
