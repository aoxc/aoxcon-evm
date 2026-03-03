// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcVault (Neural V2.2)
 * @author AOXCAN Core Division
 * @notice The Sovereign Treasury: Handles liquidity, settlements, and AI-driven recovery.
 * @dev Optimized for OZ 5.0+ (Fixed upgradeToAndCall for v5 stability).
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {IAoxcVault} from "aoxc-interfaces/IAoxcVault.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

contract AoxcVault is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, IAoxcVault {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE (DNA)
    //////////////////////////////////////////////////////////////*/

    struct RepairState {
        address proposedLogic;
        uint256 readyAt;
        bool active;
    }

    struct VaultStorage {
        address coreAsset;
        bool isSealed;
        RepairState repair;
        address[] trackedTokens;
        mapping(address => uint256) lastRefill;
    }

    // ERC-7201 compliance slot
    bytes32 private constant VAULT_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00100;

    function _getStore() internal pure returns (VaultStorage storage $) {
        assembly { $.slot := VAULT_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeVaultV2(address governor, address aoxc) external initializer {
        if (governor == address(0) || aoxc == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, governor);

        VaultStorage storage $ = _getStore();
        $.coreAsset = aoxc;
        $.trackedTokens.push(aoxc);
    }

    /*//////////////////////////////////////////////////////////////
                        TREASURY & SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        if (msg.value > 0) emit AoxcEvents.VaultFunded(msg.sender, msg.value);
    }

    function withdrawErc20(address token, address to, uint256 amount, bytes calldata)
        external
        override
        onlyRole(AoxcConstants.GOVERNANCE_ROLE)
        nonReentrant
    {
        if (to == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        VaultStorage storage $ = _getStore();
        if ($.isSealed) revert AoxcErrors.Aoxc_GlobalLockActive();

        IERC20(token).safeTransfer(to, amount);
        emit AoxcEvents.VaultWithdrawal(token, to, amount);
    }

    function withdrawEth(address payable to, uint256 amount, bytes calldata)
        external
        override
        onlyRole(AoxcConstants.GOVERNANCE_ROLE)
        nonReentrant
    {
        if (to == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        VaultStorage storage $ = _getStore();
        if ($.isSealed) revert AoxcErrors.Aoxc_GlobalLockActive();

        uint256 balance = address(this).balance;
        if (amount > balance) revert AoxcErrors.Aoxc_InsufficientBalance(balance, amount);

        (bool success,) = to.call{value: amount}("");
        if (!success) revert AoxcErrors.Aoxc_TransferFailed();

        emit AoxcEvents.VaultWithdrawal(address(0), to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL SELF-HEALING (Rule 12)
    //////////////////////////////////////////////////////////////*/

    function proposeSelfHealing(address newLogic) external override onlyRole(AoxcConstants.SENTINEL_ROLE) {
        if (newLogic == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        VaultStorage storage $ = _getStore();

        $.repair = RepairState({
            proposedLogic: newLogic, readyAt: block.timestamp + AoxcConstants.REPAIR_TIMELOCK, active: true
        });

        $.isSealed = true;
        emit AoxcEvents.GlobalLockStateChanged(true, $.repair.readyAt);
    }

    /**
     * @notice Finalizes the repair.
     * @dev In OZ v5, the upgrade is performed via upgradeToAndCall.
     */
    function finalizeSelfHealing() external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        VaultStorage storage $ = _getStore();
        RepairState memory repair = $.repair;

        if (!repair.active) revert AoxcErrors.Aoxc_Repair_ModeNotActive();
        if (block.timestamp < repair.readyAt) {
            revert AoxcErrors.Aoxc_Repair_CooldownActive(repair.readyAt - block.timestamp);
        }

        address target = repair.proposedLogic;

        delete $.repair;
        $.isSealed = false;

        emit AoxcEvents.NeuralRecoveryExecuted(address(0), target, 0);

        // FIX: Using the correct OZ v5 upgrade call
        upgradeToAndCall(target, "");
    }

    /*//////////////////////////////////////////////////////////////
                            SYSTEM INTERFACE
    //////////////////////////////////////////////////////////////*/

    function requestSettlement(address token, address to, uint256 amount)
        external
        override
        onlyRole(AoxcConstants.GOVERNANCE_ROLE)
    {
        if (_getStore().isSealed) revert AoxcErrors.Aoxc_GlobalLockActive();
        IERC20(token).safeTransfer(to, amount);
    }

    function isVaultLocked() external view override returns (bool) {
        return _getStore().isSealed;
    }

    function emergencyUnseal() external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _getStore().isSealed = false;
        emit AoxcEvents.GlobalLockStateChanged(false, block.timestamp);
    }

    function _authorizeUpgrade(address) internal view override {
        // Only allow upgrade if it's a self-call (repair) or from Governance
        if (msg.sender != address(this)) {
            _checkRole(AoxcConstants.GOVERNANCE_ROLE);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            COMPLIANCE STUBS
    //////////////////////////////////////////////////////////////*/
    function deposit() external payable override {}

    function getVaultTvl() external view override returns (uint256) {
        return address(this).balance;
    }
    function requestAutomatedRefill(uint256) external override {}

    uint256[50] private __gap;
}
