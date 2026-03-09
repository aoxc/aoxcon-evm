// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcGateway (Neural V3.0)
 * @author AOXCAN Security Architecture
 * @notice Cross-chain migration engine with Neural Proof verification.
 * @dev Optimized for OpenZeppelin 5.0+ & ERC-7201. Integrates with Sentinel V3.0.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// AOXC INFRASTRUCTURE
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {IAoxcSentinel} from "aoxc-interfaces/IAoxcSentinel.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";
// FIX: Path ve Dosya ismi senin klasör yapına göre CamelCase yapıldı
import {IAoxcGateway} from "aoxc-interfaces/IAoxcGateway.sol"; 
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

contract AoxcGateway is
    IAoxcGateway, // FIX: Interface ismi güncellendi
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE (DNA)
    //////////////////////////////////////////////////////////////*/

    struct GatewayStorage {
        address coreToken; 
        address sentinelAi; 
        address treasury; 
        uint256 minQuantum; 
        uint256 maxQuantum; 
        uint256 gatewayFeeBps; 
        uint256 migrationNonce; 
        mapping(uint16 => bool) supportedChains;
        mapping(bytes32 => bool) processedMigrations;
    }

    bytes32 private constant GATEWAY_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00800;

    function _getStore() internal pure returns (GatewayStorage storage $) {
        assembly { $.slot := GATEWAY_STORAGE_SLOT }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeGatewayV3(
        address governor, 
        address _coreToken, 
        address _sentinel, 
        address _treasury
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, governor);

        GatewayStorage storage $ = _getStore();
        $.coreToken = _coreToken;
        $.sentinelAi = _sentinel;
        $.treasury = _treasury;
        $.minQuantum = 100 * 1e18;
        $.maxQuantum = 1_000_000 * 1e18;
        $.gatewayFeeBps = 30;
    }

    /*//////////////////////////////////////////////////////////////
                        MIGRATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function initiateMigration(
        uint16 dstChainId,
        address to,
        uint256 amount,
        IAoxcCore.NeuralPacket calldata packet
    ) external payable override nonReentrant whenNotPaused {
        GatewayStorage storage $ = _getStore();

        if (!$.supportedChains[dstChainId]) revert AoxcErrors.Aoxc_ChainNotSupported(uint256(dstChainId));
        
        if (amount < $.minQuantum || amount > $.maxQuantum) {
            revert AoxcErrors.Aoxc_ExceedsMaxTransfer(amount, $.maxQuantum);
        }

        bool cleared = IAoxcSentinel($.sentinelAi).validateNeuralPacket(packet);
        if (!cleared) revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);

        uint256 fee = (amount * $.gatewayFeeBps) / AoxcConstants.BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        bytes32 migrationId = keccak256(
            abi.encode(msg.sender, to, amount, dstChainId, $.migrationNonce++, block.chainid)
        );

        if (fee > 0) IERC20($.coreToken).safeTransferFrom(msg.sender, $.treasury, fee);
        IERC20($.coreToken).safeTransferFrom(msg.sender, address(this), netAmount);

        emit MigrationInitiated(dstChainId, msg.sender, to, amount, migrationId, packet.riskScore);
    }

    function finalizeMigration(
        uint16 srcChainId,
        address to,
        uint256 amount,
        bytes32 migrationId,
        IAoxcCore.NeuralPacket calldata packet
    ) external override nonReentrant whenNotPaused {
        GatewayStorage storage $ = _getStore();

        if ($.processedMigrations[migrationId]) revert AoxcErrors.Aoxc_Neural_SignatureReused(migrationId);

        bool cleared = IAoxcSentinel($.sentinelAi).validateNeuralPacket(packet);
        if (!cleared) revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);

        $.processedMigrations[migrationId] = true;
        IERC20($.coreToken).safeTransfer(to, amount);

        emit MigrationInFinalized(srcChainId, to, amount, migrationId, packet.nonce);
    }

    /*//////////////////////////////////////////////////////////////
                            GATEWAY ANALYTICS
    //////////////////////////////////////////////////////////////*/

    function quoteGatewayFee(uint16, uint256 amount) external view override returns (uint256) {
        return (amount * _getStore().gatewayFeeBps) / AoxcConstants.BPS_DENOMINATOR;
    }

    function isNetworkSupported(uint16 chainId) external view override returns (bool) {
        return _getStore().supportedChains[chainId];
    }

    function migrationProcessed(bytes32 migrationId) external view override returns (bool) {
        return _getStore().processedMigrations[migrationId];
    }

    function getGatewayLockState() external view override returns (bool isLocked, uint256 expiry) {
        return (paused(), 0);
    }

    function getRemainingQuantum(uint16, bool) external view override returns (uint256) {
        return _getStore().maxQuantum;
    }

    function getGatewayProtocolHash() external view override returns (bytes32) {
        return keccak256("AOXC_GATEWAY_V3.0_STABLE");
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & CONFIG
    //////////////////////////////////////////////////////////////*/

    function updateChainSupport(uint16 chainId, bool status) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _getStore().supportedChains[chainId] = status;
        emit AoxcEvents.ChainSupportUpdated(chainId, status);
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
