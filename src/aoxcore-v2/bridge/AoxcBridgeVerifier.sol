// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";

/**
 * @title AoxcBridgeVerifier
 * @notice Verifies signed unified neural bridge packets for cross-chain commands.
 * @dev Replay-protected command registry for XLayer side command intake.
 */
contract AoxcBridgeVerifier is Initializable, AccessControlUpgradeable, UUPSUpgradeable, EIP712Upgradeable {
    using ECDSA for bytes32;

    enum CommandType {
        TRANSFER,
        RISK_SCORE,
        BLACKLIST,
        REPAIR
    }

    struct UnifiedNeuralPacket {
        CommandType commandType;
        address origin;
        address target;
        uint256 value;
        uint256 nonce;
        uint48 deadline;
        uint16 reasonCode;
        uint8 riskScore;
        uint256 sourceChainId;
        bytes32 payloadHash;
        bytes signature;
    }

    bytes32 private constant PACKET_TYPEHASH =
        keccak256(
            "UnifiedNeuralPacket(uint8 commandType,address origin,address target,uint256 value,uint256 nonce,uint48 deadline,uint16 reasonCode,uint8 riskScore,uint256 sourceChainId,bytes32 payloadHash)"
        );

    address public bridgeSigner;
    bool public paused;
    mapping(bytes32 => bool) public consumedPackets;
    mapping(address => uint256) public nonces;
    mapping(uint256 => bool) public supportedSourceChains;
    mapping(uint8 => bool) public enabledCommands;

    event PacketVerified(bytes32 indexed packetId, CommandType commandType, address indexed origin, address indexed target);
    event BridgeSignerUpdated(address indexed previousSigner, address indexed newSigner);
    event SourceChainSupportUpdated(uint256 indexed chainId, bool enabled);
    event CommandSupportUpdated(CommandType indexed commandType, bool enabled);
    event BridgePausedUpdated(bool pausedState);
    mapping(bytes32 => bool) public consumedPackets;
    mapping(address => uint256) public nonces;

    event PacketVerified(bytes32 indexed packetId, CommandType commandType, address indexed origin, address indexed target);

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address signer) external initializer {
        if (admin == address(0) || signer == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        __AccessControl_init();
        __EIP712_init("AoxcBridgeVerifier", "1");
        __UUPSUpgradeable_init();

        bridgeSigner = signer;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AoxcConstants.GOVERNANCE_ROLE, admin);
        _grantRole(AoxcConstants.UPGRADER_ROLE, admin);

        supportedSourceChains[AoxcConstants.CHAIN_ID_X_LAYER] = true;
        enabledCommands[uint8(CommandType.TRANSFER)] = true;
        enabledCommands[uint8(CommandType.RISK_SCORE)] = true;
        enabledCommands[uint8(CommandType.BLACKLIST)] = true;
        enabledCommands[uint8(CommandType.REPAIR)] = true;
    }

    function verifyAndConsume(UnifiedNeuralPacket calldata packet) external returns (bytes32 packetId) {
        if (paused) revert AoxcErrors.Aoxc_CustomRevert("BRIDGE: PAUSED");
        if (!enabledCommands[uint8(packet.commandType)]) revert AoxcErrors.Aoxc_CustomRevert("BRIDGE: COMMAND_DISABLED");
        if (!supportedSourceChains[packet.sourceChainId]) revert AoxcErrors.Aoxc_ChainNotSupported(packet.sourceChainId);
        if (packet.origin == address(0) || packet.target == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        _grantRole(AoxcConstants.UPGRADER_ROLE, admin);
    }

    function verifyAndConsume(UnifiedNeuralPacket calldata packet) external returns (bytes32 packetId) {
        if (packet.deadline < block.timestamp) revert AoxcErrors.Aoxc_Neural_HandshakeExpired(packet.deadline, block.timestamp);
        if (packet.nonce != nonces[packet.origin]) revert AoxcErrors.Aoxc_Neural_InvalidNonce(packet.nonce, nonces[packet.origin]);

        bytes32 structHash = keccak256(
            abi.encode(
                PACKET_TYPEHASH,
                packet.commandType,
                packet.origin,
                packet.target,
                packet.value,
                packet.nonce,
                packet.deadline,
                packet.reasonCode,
                packet.riskScore,
                packet.sourceChainId,
                packet.payloadHash
            )
        );

        address recovered = _hashTypedDataV4(structHash).recover(packet.signature);
        if (recovered != bridgeSigner) revert AoxcErrors.Aoxc_Neural_IdentityForgery();

        packetId = keccak256(abi.encode(packet.origin, packet.target, packet.nonce, packet.payloadHash, packet.sourceChainId));
        if (consumedPackets[packetId]) revert AoxcErrors.Aoxc_Neural_SignatureReused(packetId);

        consumedPackets[packetId] = true;
        nonces[packet.origin] = packet.nonce + 1;

        emit PacketVerified(packetId, packet.commandType, packet.origin, packet.target);
    }

    function setBridgeSigner(address newSigner) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        if (newSigner == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();
        address previous = bridgeSigner;
        bridgeSigner = newSigner;
        emit BridgeSignerUpdated(previous, newSigner);
    }

    function setSourceChainSupport(uint256 chainId, bool enabled) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        supportedSourceChains[chainId] = enabled;
        emit SourceChainSupportUpdated(chainId, enabled);
    }

    function setCommandSupport(CommandType commandType, bool enabled) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        enabledCommands[uint8(commandType)] = enabled;
        emit CommandSupportUpdated(commandType, enabled);
    }

    function setPaused(bool pausedState) external onlyRole(AoxcConstants.GOVERNANCE_ROLE) {
        paused = pausedState;
        emit BridgePausedUpdated(pausedState);
    }

    function _authorizeUpgrade(address) internal override onlyRole(AoxcConstants.UPGRADER_ROLE) {}
}
