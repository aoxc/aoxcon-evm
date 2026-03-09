// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcVault
 * @author AOXCAN Core Division
 * @notice The Sovereign Treasury: Handles liquidity, settlements, and AI-driven recovery.
 * @dev V2.0.0 Compliance: Integrated 10-Point Neural Handshake.
 * Optimized for OpenZeppelin v5.5.0: Replaced legacy UUPS internal calls.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {IAoxcVault} from "aoxc-interfaces/IAoxcVault.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";



contract AoxcVault is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, IAoxcVault {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                NAMESPACED STORAGE (DNA - ERC-7201)
    //////////////////////////////////////////////////////////////*/

    struct RepairState {
        address proposedLogic;
        uint256 readyAt;
        bool active;
    }

    struct VaultStorage {
        address coreAsset;
        address coreAddress; // Link to Neural Core
        bool isSealed;
        RepairState repair;
        address[] trackedTokens;
        mapping(address => uint256) lastRefill;
        uint256 initialUnlockTime;
        uint256 currentWindowId;
    }

    // ERC-7201 compliance slot
    bytes32 private constant VAULT_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00100;

    function _getStore() internal pure returns (VaultStorage storage $) {
        assembly { $.slot := VAULT_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS (V3)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Enforces the 10-Point Neural Handshake for every state-changing operation.
     */
    modifier neuralGated(IAoxcCore.NeuralPacket calldata packet) {
        VaultStorage storage $ = _getStore();
        if ($.isSealed && packet.reasonCode != AoxcConstants.REASON_REPAIR_OVERRIDE) {
            revert AoxcErrors.Aoxc_GlobalLockActive();
        }
        // Verification at Core Level (Rule 1-10)
        if (!IAoxcCore($.coreAddress).executeNeuralAction(packet)) {
            revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeVaultV2(address core, address aoxc, address admin) external initializer {
        if (core == address(0) || aoxc == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, core);

        VaultStorage storage $ = _getStore();
        $.coreAddress = core;
        $.coreAsset = aoxc;
        $.trackedTokens.push(aoxc);
        $.initialUnlockTime = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                         TREASURY & SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        if (msg.value > 0) emit AoxcEvents.VaultFunded(msg.sender, msg.value);
    }

    function withdrawErc20(
        address token,
        address to,
        uint256 amount,
        IAoxcCore.NeuralPacket calldata packet
    ) external override neuralGated(packet) nonReentrant {
        if (to == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        if (amount != packet.value) revert AoxcErrors.Aoxc_Neural_ValueMismatch(amount, packet.value);

        IERC20(token).safeTransfer(to, amount);
        emit AoxcEvents.VaultWithdrawal(token, to, packet.nonce, amount);
    }

    function withdrawEth(
        address payable to,
        uint256 amount,
        IAoxcCore.NeuralPacket calldata packet
    ) external override neuralGated(packet) nonReentrant {
        if (to == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        
        uint256 balance = address(this).balance;
        if (amount > balance) revert AoxcErrors.Aoxc_InsufficientBalance(balance, amount);

        (bool success,) = to.call{value: amount}("");
        if (!success) revert AoxcErrors.Aoxc_TransferFailed();

        emit AoxcEvents.VaultWithdrawal(address(0), to, packet.nonce, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL SELF-HEALING (Rule 12)
    //////////////////////////////////////////////////////////////*/

    function proposeSelfHealing(
        address newLogic,
        IAoxcCore.NeuralPacket calldata packet
    ) external override neuralGated(packet) onlyRole(AoxcConstants.SENTINEL_ROLE) {
        if (newLogic == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        VaultStorage storage $ = _getStore();

        $.repair = RepairState({
            proposedLogic: newLogic, 
            readyAt: block.timestamp + AoxcConstants.REPAIR_TIMELOCK, 
            active: true
        });

        $.isSealed = true;
        emit AoxcEvents.GlobalLockStateChanged(true, 0, $.repair.readyAt);
    }

    function finalizeSelfHealing(
        IAoxcCore.NeuralPacket calldata packet
    ) external override neuralGated(packet) onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        VaultStorage storage $ = _getStore();
        if (!$.repair.active) revert AoxcErrors.Aoxc_Repair_ModeNotActive();
        if (block.timestamp < $.repair.readyAt) {
            revert AoxcErrors.Aoxc_Repair_CooldownActive($.repair.readyAt - block.timestamp);
        }

        address target = $.repair.proposedLogic;
        delete $.repair;
        $.isSealed = false;

        emit AoxcEvents.NeuralRecoveryExecuted(address(0), target, 0, packet.protocolHash);

        // FIX: OZ v5.0+ uses upgradeToAndCall instead of _upgradeToAndCallUUPS
        upgradeToAndCall(target, "");
    }

    /*//////////////////////////////////////////////////////////////
                            SYSTEM INTERFACE
    //////////////////////////////////////////////////////////////*/

    function requestSettlement(
        address token,
        address to,
        uint256 amount,
        IAoxcCore.NeuralPacket calldata packet
    ) external override neuralGated(packet) onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        IERC20(token).safeTransfer(to, amount);
    }

    function isVaultLocked() external view override returns (bool) {
        return _getStore().isSealed;
    }

    function emergencyUnseal(
        IAoxcCore.NeuralPacket calldata packet
    ) external override neuralGated(packet) onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _getStore().isSealed = false;
        emit AoxcEvents.GlobalLockStateChanged(false, 0, block.timestamp);
    }

    function _authorizeUpgrade(address) internal view override {
        // Upgrade is controlled via Neural Handshake in finalizeSelfHealing
        if (msg.sender != address(this)) {
            _checkRole(AoxcConstants.GOVERNANCE_ROLE);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEWS & STUBS
    //////////////////////////////////////////////////////////////*/

    function getVaultTvl() external view override returns (uint256) { return address(this).balance; }
    function getInitialUnlockTime() external view override returns (uint256) { return _getStore().initialUnlockTime; }
    function getCurrentWindowId() external view override returns (uint256) { return _getStore().currentWindowId; }
    function getCurrentWindowEnd() external view override returns (uint256) { return block.timestamp; }
    function getRemainingLimit(address) external view override returns (uint256) { return 1_000_000 * 1e18; }

    function deposit() external payable override {}
    function toggleEmergencyMode(bool, IAoxcCore.NeuralPacket calldata) external override {}
    function openNextWindow(IAoxcCore.NeuralPacket calldata) external override {}
    function requestAutomatedRefill(uint256, IAoxcCore.NeuralPacket calldata) external override {}
    function emergencyNeuralRecovery(address, address, uint256, IAoxcCore.NeuralPacket calldata) external override {}

    uint256[50] private __gap;
}
