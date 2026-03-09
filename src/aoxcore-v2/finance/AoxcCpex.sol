// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcCpex
 * @author AOXCAN Finance & AI Division
 * @notice Enterprise-grade yield engine with Neural-Pulse Reputation Scaling.
 * @dev V2.0.0: Enforces the 10-Point Neural Handshake for secure staking and meritocracy.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AOXC INTERNAL
import {IAoxcCpex} from "aoxc-interfaces/IAoxcCpex.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";



contract AoxcCpex is IAoxcCpex, Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                NAMESPACED STORAGE (DNA - ERC-7201)
    //////////////////////////////////////////////////////////////*/

    struct StakingStorage {
        uint256 totalValueLocked;
        uint256 baseYieldRateBps;
        uint256 attritionPenaltyBps;
        uint256 minLockdownDuration;
        mapping(address => IAoxcCpex.PositionInfo[]) accountPositions;
    }

    struct MainStorage {
        address coreAddress;
        address coreAssetToken;
        address treasury;
        address aiNode;
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
                          CONSTRUCTOR & INIT
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeCpexV2(address core, address token, address treasury, address ai) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, core);

        MainStorage storage main = _getMainStore();
        StakingStorage storage stake = _getStakeStore();

        main.coreAddress = core;
        main.coreAssetToken = token;
        main.treasury = treasury;
        main.aiNode = ai;

        stake.baseYieldRateBps = AoxcConstants.STAKING_REWARD_APR_BPS;
        stake.attritionPenaltyBps = 1500; // 15% Standard Attrition
        stake.minLockdownDuration = 90 days;
    }

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IAoxcCpex
     * @dev Implements Rule 1, 3, 5 & 7. Validates amount and duration through AI seal.
     */
    function openPosition(
        uint256 amount, 
        uint256 duration, 
        IAoxcCore.NeuralPacket calldata packet
    ) external override nonReentrant {
        MainStorage storage main = _getMainStore();
        StakingStorage storage stake = _getStakeStore();

        // 10-Point Neural Handshake (Rule 1-10 Validation)
        _verifyNeuralHandshake(main.coreAddress, packet);

        if (main.isSovereignVaultSealed) revert AoxcErrors.Aoxc_GlobalLockActive();
        if (amount == 0) revert AoxcErrors.Aoxc_ZeroAmount();
        if (amount != packet.value) revert AoxcErrors.Aoxc_Neural_ValueMismatch(amount, packet.value);

        stake.totalValueLocked += amount;
        stake.accountPositions[msg.sender].push(
            IAoxcCpex.PositionInfo({
                principal: uint128(amount),
                entryTime: uint64(block.timestamp),
                lockPeriod: uint64(duration),
                neuralBoost: uint64(packet.riskScore == 0 ? 10000 : 8000), // AI Merit Scaler
                isActive: true
            })
        );

        IERC20(main.coreAssetToken).safeTransferFrom(msg.sender, address(this), amount);

        emit AoxcEvents.PositionOpened(msg.sender, stake.accountPositions[msg.sender].length - 1, amount, packet.riskScore);
    }

    /**
     * @inheritdoc IAoxcCpex
     * @dev Implements Rule 4 & 10. Sequential nonce check performed at Core.
     */
    function closePosition(
        uint256 index, 
        IAoxcCore.NeuralPacket calldata packet
    ) external override nonReentrant {
        MainStorage storage main = _getMainStore();
        StakingStorage storage stake = _getStakeStore();

        _verifyNeuralHandshake(main.coreAddress, packet);

        IAoxcCpex.PositionInfo[] storage positions = stake.accountPositions[msg.sender];
        if (index >= positions.length) revert AoxcErrors.Aoxc_Module_Error(10, 404);

        IAoxcCpex.PositionInfo storage pos = positions[index];
        if (!pos.isActive) revert AoxcErrors.Aoxc_CustomRevert("CPEX: ALREADY_CLOSED");

        uint256 elapsedTime = block.timestamp - pos.entryTime;
        uint256 principal = uint256(pos.principal);
        uint256 penalty;
        bool isEarly = elapsedTime < pos.lockPeriod;

        if (isEarly) {
            penalty = (principal * stake.attritionPenaltyBps) / AoxcConstants.BPS_DENOMINATOR;
            principal -= penalty;
        }

        uint256 yield = calculateYield(msg.sender, index);
        
        stake.totalValueLocked -= uint256(pos.principal);
        pos.isActive = false;

        IERC20(main.coreAssetToken).safeTransfer(msg.sender, principal + yield);
        
        if (penalty > 0 && main.treasury != address(0)) {
            IERC20(main.coreAssetToken).safeTransfer(main.treasury, penalty);
        }

        emit AoxcEvents.PositionClosed(msg.sender, principal + yield, penalty, packet.nonce);
    }

    /*//////////////////////////////////////////////////////////////
                        DEFENSIVE & ANALYTIC VIEWS
    //////////////////////////////////////////////////////////////*/

    function calculateYield(address user, uint256 index) public view override returns (uint256 yield) {
        StakingStorage storage stake = _getStakeStore();
        IAoxcCpex.PositionInfo storage pos = stake.accountPositions[user][index];
        
        if (!pos.isActive) return 0;

        uint256 duration = (block.timestamp - pos.entryTime) > pos.lockPeriod ? pos.lockPeriod : (block.timestamp - pos.entryTime);
        
        // Yield = (Principal * Time * BaseRate * NeuralBoost) / (Year * BPS * BoostDenominator)
        return (uint256(pos.principal) * duration * stake.baseYieldRateBps * uint256(pos.neuralBoost)) 
            / (365 days * AoxcConstants.BPS_DENOMINATOR * 10000);
    }

    function getAccountMerit(address user) external view override returns (uint256 merit) {
        return _getStakeStore().accountPositions[user].length * 100; // Base merit per position
    }

    function getPexLockState() external view override returns (bool isLocked, uint256 expiry) {
        return (_getMainStore().isSovereignVaultSealed, 0);
    }

    function getPositionDetails(address user, uint256 index) external view override returns (PositionInfo memory) {
        return _getStakeStore().accountPositions[user][index];
    }

    function getModuleTvl() external view override returns (uint256) {
        return _getStakeStore().totalValueLocked;
    }

    function getPositionCount(address user) external view override returns (uint256) {
        return _getStakeStore().accountPositions[user].length;
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & SYSTEM OPS
    //////////////////////////////////////////////////////////////*/

    function updateBaseYield(uint256 newRateBps, IAoxcCore.NeuralPacket calldata packet) external override {
        MainStorage storage main = _getMainStore();
        _verifyNeuralHandshake(main.coreAddress, packet);
        _checkRole(AoxcConstants.GOVERNANCE_ROLE);
        
        uint256 oldRate = _getStakeStore().baseYieldRateBps;
        _getStakeStore().baseYieldRateBps = newRateBps;
        
        emit YieldRateUpdated(oldRate, newRateBps, packet.protocolHash);
    }

    function updateAiNode(address newNode, IAoxcCore.NeuralPacket calldata packet) external override {
        MainStorage storage main = _getMainStore();
        _verifyNeuralHandshake(main.coreAddress, packet);
        _checkRole(DEFAULT_ADMIN_ROLE);
        
        main.aiNode = newNode;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates the 10-Point Neural Handshake via Core module.
     */
    function _verifyNeuralHandshake(address core, IAoxcCore.NeuralPacket calldata packet) internal {
        if (packet.origin != msg.sender) revert AoxcErrors.Aoxc_Neural_InvalidOrigin();
        if (packet.target != address(this)) revert AoxcErrors.Aoxc_Neural_InvalidTarget();
        
        // External call to Core for sequential nonce and signature verification
        if (!IAoxcCore(core).executeNeuralAction(packet)) {
            revert AoxcErrors.Aoxc_Neural_SecurityVeto(address(0), packet.riskScore);
        }
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {}
}
