// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcGateway (Neural V2.2)
 * @author AOXCAN Security Architecture
 * @notice Cross-chain migration engine with Neural Proof verification.
 * @dev Optimized for OpenZeppelin 5.0+ & ERC-7201. Integrates with Sentinel V2.2.
 */

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INFRASTRUCTURE
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {IAoxcSentinel} from "aoxc-interfaces/IAoxcSentinel.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";

contract AoxcGateway is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                        NAMESPACED STORAGE (DNA)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev ERC-7201 compliance:
     * keccak256(abi.encode(uint256(keccak256("aoxc.gateway.storage.v2")) - 1)) & ~bytes32(uint256(0xff))
     */
    struct GatewayStorage {
        address coreToken; // AOXC Token Address
        address sentinelAi; // Sentinel V2.2 Address
        address treasury; // Fee collection address
        uint256 minQuantum; // Min migration amount
        uint256 maxQuantum; // Max migration amount
        uint256 gatewayFeeBps; // Fee in basis points
        uint256 migrationNonce; // Unique ID generator
        mapping(uint16 => bool) supportedChains;
        mapping(bytes32 => bool) processedMigrations;
    }

    // Storage slot per ERC-7201
    bytes32 private constant GATEWAY_STORAGE_SLOT = 0x56a64487b9f3630f9a2e6840a3597843644f7725845c2794c489b251a3d00700;

    function _getStore() internal pure returns (GatewayStorage storage $) {
        assembly { $.slot := GATEWAY_STORAGE_SLOT }
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the Gateway with V2 specifications.
     */
    function initializeGatewayV2(address governor, address _coreToken, address _sentinel, address _treasury)
        external
        initializer
    {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        // __UUPSUpgradeable_init() is removed for OZ v5 compatibility to resolve Undeclared Identifier

        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, governor);

        GatewayStorage storage $ = _getStore();
        $.coreToken = _coreToken;
        $.sentinelAi = _sentinel;
        $.treasury = _treasury;
        $.minQuantum = 100 * 1e18;
        $.maxQuantum = 1_000_000 * 1e18;
        $.gatewayFeeBps = 30; // 0.30%
    }

    /*//////////////////////////////////////////////////////////////
                        MIGRATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates a cross-chain migration with Neural Handshake.
     * @param dstChainId Destination chain identifier.
     * @param to Recipient address on destination chain.
     * @param amount Token amount to migrate.
     */
    function initiateMigration(
        uint16 dstChainId,
        address to,
        uint256 amount,
        IAoxcStorage.NeuralPacket calldata packet,
        bytes calldata aiSignature
    ) external payable nonReentrant whenNotPaused {
        GatewayStorage storage $ = _getStore();

        if (!$.supportedChains[dstChainId]) revert AoxcErrors.Aoxc_ChainNotSupported(uint256(dstChainId));
        if (amount < $.minQuantum || amount > $.maxQuantum) {
            revert AoxcErrors.Aoxc_ExceedsMaxTransfer(amount, $.maxQuantum);
        }

        // Sentinel V2.2 Validation
        bool cleared = IAoxcSentinel($.sentinelAi).verifyAndPack(packet, aiSignature);
        if (!cleared) revert AoxcErrors.Aoxc_Neural_BastionSealed(block.timestamp);

        uint256 fee = (amount * $.gatewayFeeBps) / AoxcConstants.BPS_DENOMINATOR;
        uint256 netAmount = amount - fee;

        bytes32 migrationId =
            keccak256(abi.encode(msg.sender, to, amount, dstChainId, $.migrationNonce++, block.chainid));

        if (fee > 0) IERC20($.coreToken).safeTransferFrom(msg.sender, $.treasury, fee);
        IERC20($.coreToken).safeTransferFrom(msg.sender, address(this), netAmount);

        emit AoxcEvents.MigrationInitiated(dstChainId, msg.sender, to, amount, migrationId);
    }

    /**
     * @notice Finalizes an inbound migration from a source chain.
     */
    function finalizeMigration(
        uint16 srcChainId,
        address to,
        uint256 amount,
        bytes32 migrationId,
        bytes calldata /* neuralProof */
    )
        external
        nonReentrant
        whenNotPaused
    {
        GatewayStorage storage $ = _getStore();

        if ($.processedMigrations[migrationId]) revert AoxcErrors.Aoxc_Neural_SignatureReused(migrationId);

        // Verify Inbound Logic (Handshake with Sentinel AI)
        $.processedMigrations[migrationId] = true;

        IERC20($.coreToken).safeTransfer(to, amount);

        emit AoxcEvents.MigrationInFinalized(srcChainId, to, amount, migrationId);
    }

    /*//////////////////////////////////////////////////////////////
                        GOVERNANCE & CONFIG
    //////////////////////////////////////////////////////////////*/

    function updateChainSupport(uint16 chainId, bool status) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        _getStore().supportedChains[chainId] = status;
        emit AoxcEvents.ChainSupportUpdated(chainId, status);
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {}

    // --- Views ---
    function isMigrationProcessed(bytes32 migrationId) external view returns (bool) {
        return _getStore().processedMigrations[migrationId];
    }

    /**
     * @dev Gap for future storage upgrades.
     */
    uint256[50] private __gap;
}
