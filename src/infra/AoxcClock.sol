// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcClock (Neural V3.2)
 * @author AOXCAN Infrastructure Division
 * @notice Neural-integrated Timelock and Synchronous Pulse Engine.
 * @dev Implements Rule 13 (Temporal Security) and Rule 14 (Neural Veto).
 */

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {AoxcConstants} from "../libraries/AoxcConstants.sol";
import {AoxcErrors} from "../libraries/AoxcErrors.sol";
import {AoxcEvents} from "../libraries/AoxcEvents.sol";
import {AoxcStorage} from "../abstract/AoxcStorage.sol";
import {IAoxcClock} from "../interfaces/IAoxcClock.sol";

contract AoxcClock is
    IAoxcClock,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable, // FIX 1: Inheritance added
    AoxcStorage
{
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /**
     * @dev ERC-7201 Storage Slot for Clock logic.
     */
    bytes32 private constant CLOCK_STORAGE_LOCATION =
        0x82b9e60799464a93a1c1d8595245892345892345892345892345892345892300;

    struct NeuralTimelockStorage {
        address aoxcanNode;
        uint256 anomalyThreshold;
        uint256 neuralNonce;
        uint256 maxNeuralDelay;
        uint256 lastPulse;
        mapping(address => uint256) targetSecurityTier;
        mapping(bytes32 => uint256) timestamps;
        bool isInitialized;
    }

    function _getNeural() internal pure returns (NeuralTimelockStorage storage $) {
        bytes32 slot = CLOCK_STORAGE_LOCATION;
        assembly { $.slot := slot }
    }

    /*//////////////////////////////////////////////////////////////
                                INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeLockV3(address admin, address aiNode) external initializer {
        if (admin == address(0) || aiNode == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init(); // FIX 2: Guard initialized
        // __UUPSUpgradeable_init(); // FIX 3: Removed for OZ v5

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, admin);
        _grantRole(AoxcConstants.SENTINEL_ROLE, aiNode);
        _grantRole(AoxcConstants.UPGRADER_ROLE, admin);

        NeuralTimelockStorage storage $ = _getNeural();
        $.aoxcanNode = aiNode;
        $.anomalyThreshold = AoxcConstants.AI_RISK_THRESHOLD_HIGH;
        $.maxNeuralDelay = 26 days;
        $.lastPulse = block.timestamp;
        $.isInitialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                        TEMPORAL SCHEDULING
    //////////////////////////////////////////////////////////////*/

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        NeuralTimelockStorage storage $ = _getNeural();
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        if ($.timestamps[id] != 0) revert AoxcErrors.Aoxc_CustomRevert("CLOCK: ALREADY_SCHEDULED");

        uint256 minDelay = $.targetSecurityTier[target];
        if (delay < minDelay) revert AoxcErrors.Aoxc_CustomRevert("CLOCK: DELAY_TOO_SHORT");

        $.timestamps[id] = block.timestamp + delay;

        emit AoxcEvents.UpgradeScheduled(target, $.timestamps[id]);
    }

    function execute(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        payable
        override
        nonReentrant
    {
        // Now works!
        NeuralTimelockStorage storage $ = _getNeural();
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        uint256 ts = $.timestamps[id];

        if (ts == 0) revert AoxcErrors.Aoxc_NOT_SCHEDULED();
        if (block.timestamp < ts) revert AoxcErrors.Aoxc_TemporalBreach(block.timestamp, ts);

        if (predecessor != bytes32(0) && $.timestamps[predecessor] != 0) {
            revert AoxcErrors.Aoxc_TemporalCollision();
        }

        delete $.timestamps[id];

        (bool success,) = target.call{value: value}(data);
        if (!success) revert AoxcErrors.Aoxc_ExecutionFailed();

        emit AoxcEvents.ProposalExecuted(uint256(id));
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL VETO & HEARTBEAT
    //////////////////////////////////////////////////////////////*/

    function neuralEscalation(bytes32 id, uint256 riskScore, bytes calldata signature) external override {
        NeuralTimelockStorage storage $ = _getNeural();

        if (riskScore < $.anomalyThreshold) {
            revert AoxcErrors.Aoxc_Neural_RiskThresholdBreached(riskScore, $.anomalyThreshold);
        }

        bytes32 msgHash = keccak256(abi.encode(id, riskScore, $.neuralNonce, address(this))).toEthSignedMessageHash();
        if (msgHash.recover(signature) != $.aoxcanNode) revert AoxcErrors.Aoxc_Neural_IdentityForgery();

        $.neuralNonce++;
        delete $.timestamps[id];

        emit AoxcEvents.KarujanNeuralVeto(uint256(id), riskScore);
    }

    function pulse() external {
        _getNeural().lastPulse = block.timestamp;
        emit AoxcEvents.HeartbeatSynced(block.timestamp, block.timestamp + AoxcConstants.NEURAL_HEARTBEAT_TIMEOUT);
    }

    /*//////////////////////////////////////////////////////////////
                             UPGRADEABILITY
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {
        if (newImplementation == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function getClockLockState() external view override returns (bool isLocked, uint256 expiry) {
        NeuralTimelockStorage storage $ = _getNeural();
        uint256 timeout = AoxcConstants.NEURAL_HEARTBEAT_TIMEOUT;
        isLocked = block.timestamp > $.lastPulse + timeout;
        expiry = $.lastPulse + timeout;
    }

    function isOperationReady(bytes32 id) public view override returns (bool) {
        uint256 ts = _getNeural().timestamps[id];
        return ts > 0 && block.timestamp >= ts;
    }

    receive() external payable {}

    uint256[50] private __gap;
}
