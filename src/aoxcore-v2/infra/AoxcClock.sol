// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcClock
 * @author AOXCAN Infrastructure Division
 * @notice Neural-integrated Timelock and Synchronous Pulse Engine.
 * @dev V2.0.0 Genesis Compliance: Integrated 10-Point Neural Handshake (Rule 13).
 */

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {AoxcConstants} from "../libraries/AoxcConstants.sol";
import {AoxcErrors} from "../libraries/AoxcErrors.sol";
import {AoxcEvents} from "../libraries/AoxcEvents.sol";
import {IAoxcCore} from "../interfaces/IAoxcCore.sol";
import {IAoxcClock} from "../interfaces/IAoxcClock.sol";

contract AoxcClock is
    IAoxcClock,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                NAMESPACED STORAGE (DNA - ERC-7201)
    //////////////////////////////////////////////////////////////*/

    struct NeuralTimelockStorage {
        address core;
        uint256 anomalyThreshold;
        uint256 lastPulse;
        mapping(address => uint256) targetSecurityTier;
        mapping(bytes32 => uint256) timestamps;
        mapping(bytes32 => bool) operationDone;
    }

    // keccak256(abi.encode(uint256(keccak256("aoxc.clock.storage.v2")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CLOCK_STORAGE_LOCATION =
        0x82b9e60799464a93a1c1d8595245892345892345892345892345892345892300;

    function _getStore() internal pure returns (NeuralTimelockStorage storage $) {
        assembly { $.slot := CLOCK_STORAGE_LOCATION }
    }

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS (V3)
    //////////////////////////////////////////////////////////////*/

    modifier neuralGated(IAoxcCore.NeuralPacket calldata packet) {
        if (!IAoxcCore(_getStore().core).executeNeuralAction(packet)) {
            revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initializeClockV2(address _admin, address _core) external initializer {
        if (_admin == address(0) || _core == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, _core);
        _grantRole(AoxcConstants.UPGRADER_ROLE, _admin);

        NeuralTimelockStorage storage $ = _getStore();
        $.core = _core;
        $.lastPulse = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                        TEMPORAL SCHEDULING (IAoxcClock)
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IAoxcClock
     * @dev FIX: Added missing isOperationReady implementation to resolve Error (3656).
     */
    function isOperationReady(bytes32 id) external view override returns (bool) {
        uint256 readyAt = _getStore().timestamps[id];
        return readyAt > 0 && block.timestamp >= readyAt;
    }

    /**
     * @inheritdoc IAoxcClock
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        IAoxcCore.NeuralPacket calldata packet
    ) external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) neuralGated(packet) {
        NeuralTimelockStorage storage $ = _getStore();
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        if ($.timestamps[id] != 0) revert AoxcErrors.Aoxc_CustomRevert("CLOCK: ALREADY_SCHEDULED");

        uint256 minDelay = $.targetSecurityTier[target];
        // Note: minDelay can be updated by setTargetSecurityTier via neural verification
        $.timestamps[id] = block.timestamp + minDelay;

        emit OperationScheduled(id, target, value, minDelay, packet.riskScore);
    }

    /**
     * @inheritdoc IAoxcClock
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        IAoxcCore.NeuralPacket calldata packet
    ) external payable override nonReentrant neuralGated(packet) {
        NeuralTimelockStorage storage $ = _getStore();
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        uint256 readyAt = $.timestamps[id];

        if (readyAt == 0) revert AoxcErrors.Aoxc_NOT_SCHEDULED();
        if (block.timestamp < readyAt) revert AoxcErrors.Aoxc_TemporalBreach(block.timestamp, readyAt);
        if (predecessor != bytes32(0) && !$.operationDone[predecessor]) revert AoxcErrors.Aoxc_TemporalCollision();

        $.operationDone[id] = true;
        delete $.timestamps[id];

        (bool success, ) = target.call{value: value}(data);
        if (!success) revert AoxcErrors.Aoxc_ExecutionFailed();

        emit OperationExecuted(id, target, value);
    }

    /**
     * @inheritdoc IAoxcClock
     */
    function cancel(bytes32 id, IAoxcCore.NeuralPacket calldata packet) 
        external 
        override 
        onlyRole(AoxcConstants.GOVERNANCE_ROLE) 
        neuralGated(packet) 
    {
        delete _getStore().timestamps[id];
        emit OperationCancelled(id, packet.reasonCode);
    }

    /*//////////////////////////////////////////////////////////////
                        NEURAL ESCALATION & PULSE
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IAoxcClock
     */
    function neuralEscalation(bytes32 id, IAoxcCore.NeuralPacket calldata packet) 
        external 
        override 
        neuralGated(packet) 
    {
        uint256 oldTimestamp = _getStore().timestamps[id];
        // Risk-based dynamic delay increase
        uint256 newDelay = packet.riskScore * 1 hours; 
        _getStore().timestamps[id] = block.timestamp + newDelay;
        
        emit NeuralRiskEscalation(id, packet.riskScore, newDelay);
    }

    function pulse() external {
        _getStore().lastPulse = block.timestamp;
        emit AoxcEvents.HeartbeatSynced(block.timestamp, block.timestamp + AoxcConstants.NEURAL_HEARTBEAT_TIMEOUT);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEWS & CONFIG
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IAoxcClock
     */
    function setTargetSecurityTier(
        address target, 
        uint256 minDelay, 
        IAoxcCore.NeuralPacket calldata packet
    ) external override onlyRole(AoxcConstants.GOVERNANCE_ROLE) neuralGated(packet) {
        _getStore().targetSecurityTier[target] = minDelay;
    }

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        public pure override returns (bytes32) {
        return keccak256(abi.encode(target, value, data, predecessor, salt));
    }

    function getTimestamp(bytes32 id) external view override returns (uint256) { return _getStore().timestamps[id]; }
    function isOperation(bytes32 id) external view override returns (bool) { return _getStore().timestamps[id] > 0; }
    function isOperationPending(bytes32 id) external view override returns (bool) { return _getStore().timestamps[id] > block.timestamp; }
    function isOperationDone(bytes32 id) external view override returns (bool) { return _getStore().operationDone[id]; }
    function getMinDelayForTarget(address target) external view override returns (uint256) { return _getStore().targetSecurityTier[target]; }

    function getClockLockState() external view override returns (bool isLocked, uint256 expiry) {
        NeuralTimelockStorage storage $ = _getStore();
        uint256 timeout = AoxcConstants.NEURAL_HEARTBEAT_TIMEOUT;
        isLocked = block.timestamp > $.lastPulse + timeout;
        expiry = $.lastPulse + timeout;
    }

    /*//////////////////////////////////////////////////////////////
                            UPGRADEABILITY
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}

    receive() external payable {}
}
