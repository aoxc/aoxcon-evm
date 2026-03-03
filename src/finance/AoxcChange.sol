// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcChange (Neural V2.2)
 * @author AOXCAN Finance Division
 * @notice Autonomous swap engine with drawer-based liquidity & automated refills.
 * @dev Optimized for OpenZeppelin 5.0+ & ERC-7201.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AOXC INTERNAL
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

interface IVault {
    function requestSettlement(address token, address to, uint256 amount) external;
    function requestAutomatedRefill(uint256 amount) external;
}

interface IAoxcOracle {
    function getPriceData(address tIn, address tOut) external view returns (uint256 price, uint256 timestamp);
}

contract AoxcChange is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE (DNA)
    //////////////////////////////////////////////////////////////*/

    struct Drawer {
        uint256 aoxcStock;
        uint256 refillThreshold;
        uint256 refillAmount;
        bool isEnabled;
    }

    struct ExchangeStorage {
        address vault;
        address aoxc;
        address oracle;
        uint256 globalSlippageToleranceBps;
        mapping(address => Drawer) drawers;
    }

    // ERC-7201 compliance: keccak256(abi.encode(uint256(keccak256("aoxc.exchange.storage.v2")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EXCHANGE_STORAGE_SLOT = 0x6e8a379103c861f778393e9e6f2bc8b671d1796c739a8976136f78816f1f6c00;

    function _getStore() internal pure returns (ExchangeStorage storage $) {
        assembly { $.slot := EXCHANGE_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeChangeV2(address dao, address vault, address aoxc, address oracle) external initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        // __UUPSUpgradeable_init() is removed to fix "Undeclared Identifier" in OZ v5

        _grantRole(DEFAULT_ADMIN_ROLE, dao);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, dao);
        _grantRole(AoxcConstants.UPGRADER_ROLE, dao);

        ExchangeStorage storage $ = _getStore();
        $.vault = vault;
        $.aoxc = aoxc;
        $.oracle = oracle;
        $.globalSlippageToleranceBps = 100; // 1% default
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a token swap using the Aoxc Vault as the liquidity source.
     */
    function executeSwap(address tIn, address tOut, uint256 amountIn, uint256 minAmountOut) external nonReentrant {
        ExchangeStorage storage $ = _getStore();
        if (tIn == address(0) || tOut == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        uint256 amountOut = _calculatePrice($, tIn, tOut, amountIn);

        uint256 slippageLimit = (amountOut * (AoxcConstants.BPS_DENOMINATOR - $.globalSlippageToleranceBps))
            / AoxcConstants.BPS_DENOMINATOR;

        if (amountOut < minAmountOut || amountOut < slippageLimit) {
            revert AoxcErrors.Aoxc_CustomRevert("EXCHANGE: SLIPPAGE_BREACH");
        }

        if (tOut == $.aoxc) {
            _processDrawerRefill($, tIn, amountOut);
        }

        IERC20(tIn).safeTransferFrom(msg.sender, $.vault, amountIn);
        IVault($.vault).requestSettlement(tOut, msg.sender, amountOut);

        emit AoxcEvents.SwapExecuted(msg.sender, tIn, tOut, amountIn, amountOut);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL MECHANICS
    //////////////////////////////////////////////////////////////*/

    function _processDrawerRefill(ExchangeStorage storage $, address asset, uint256 amountOut) internal {
        Drawer storage drawer = $.drawers[asset];
        if (!drawer.isEnabled) revert AoxcErrors.Aoxc_CustomRevert("EXCHANGE: PAIR_DISABLED");
        if (drawer.aoxcStock < amountOut) revert AoxcErrors.Aoxc_CustomRevert("EXCHANGE: DRAWER_EMPTY");

        unchecked {
            drawer.aoxcStock -= amountOut;
        }

        if (drawer.aoxcStock < drawer.refillThreshold && drawer.refillAmount > 0) {
            try IVault($.vault).requestAutomatedRefill(drawer.refillAmount) {
                drawer.aoxcStock += drawer.refillAmount;
                emit AoxcEvents.DrawerSynchronized(asset, drawer.aoxcStock);
            } catch {
                emit AoxcEvents.AutonomousCorrectionFailed(
                    keccak256("EXCHANGE_REFILL"), "VAULT_REFUSAL", block.timestamp
                );
            }
        }
    }

    function _calculatePrice(ExchangeStorage storage $, address tIn, address tOut, uint256 amountIn)
        internal
        view
        returns (uint256)
    {
        (uint256 price, uint256 ts) = IAoxcOracle($.oracle).getPriceData(tIn, tOut);

        if (block.timestamp > ts + 1 hours) revert AoxcErrors.Aoxc_CustomRevert("EXCHANGE: STALE_ORACLE");

        return (amountIn * price) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                            GOVERNANCE & CONFIG
    //////////////////////////////////////////////////////////////*/

    function configureDrawer(address asset, uint256 threshold, uint256 refill, bool status)
        external
        onlyRole(AoxcConstants.GOVERNANCE_ROLE)
    {
        Drawer storage drawer = _getStore().drawers[asset];
        drawer.refillThreshold = threshold;
        drawer.refillAmount = refill;
        drawer.isEnabled = status;
        emit AoxcEvents.DrawerSynchronized(asset, drawer.aoxcStock);
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    /**
     * @dev Reserved space for future upgrades.
     */
    uint256[50] private __gap;
}
