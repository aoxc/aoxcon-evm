// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {AoxconXasToken} from "./AoxconXasToken.sol";
import {AoxconVerifierRegistry, IAoxconZkVerifier} from "./AoxconVerifierRegistry.sol";

contract AoxconBridge is Initializable, AccessControlUpgradeable, EIP712Upgradeable, UUPSUpgradeable {
    using ECDSA for bytes32;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    bytes32 public constant TICKET_TYPEHASH = keccak256(
        "BridgeTicket(address user,uint256 amount,uint256 sourceChainId,uint256 targetChainId,uint256 nonce,uint256 deadline,bytes32 refId,uint8 direction)"
    );

    enum Direction {
        Inbound,
        Outbound
    }

    struct BridgeTicket {
        address user;
        uint256 amount;
        uint256 sourceChainId;
        uint256 targetChainId;
        uint256 nonce;
        uint256 deadline;
        bytes32 refId;
        Direction direction;
    }

    AoxconXasToken public xas;
    AoxconVerifierRegistry public verifierRegistry;

    address public signer;
    mapping(address user => uint256 nonce) public nonces;
    mapping(bytes32 opId => bool used) public consumed;

    event SignerUpdated(address indexed oldSigner, address indexed newSigner);
    event InboundFinalized(address indexed user, uint256 amount, uint256 indexed sourceChainId, bytes32 indexed opId);
    event OutboundFinalized(address indexed user, uint256 amount, uint256 indexed targetChainId, bytes32 indexed opId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address xasToken, address registry, address initialSigner) external initializer {
        require(admin != address(0), "BRIDGE: ZERO_ADMIN");
        require(xasToken != address(0), "BRIDGE: ZERO_XAS");
        require(registry != address(0), "BRIDGE: ZERO_REGISTRY");
        require(initialSigner != address(0), "BRIDGE: ZERO_SIGNER");

        __AccessControl_init();
        __EIP712_init("AOXCON Bridge", "1");
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);

        xas = AoxconXasToken(xasToken);
        verifierRegistry = AoxconVerifierRegistry(registry);
        signer = initialSigner;
    }

    function setSigner(address newSigner) external onlyRole(CONFIG_ROLE) {
        require(newSigner != address(0), "BRIDGE: ZERO_SIGNER");
        address oldSigner = signer;
        signer = newSigner;
        emit SignerUpdated(oldSigner, newSigner);
    }

    function inboundMint(BridgeTicket calldata ticket, bytes calldata signature, bytes calldata zkProof) external {
        require(ticket.direction == Direction.Inbound, "BRIDGE: BAD_DIRECTION");
        require(ticket.targetChainId == block.chainid, "BRIDGE: WRONG_TARGET");

        _validateTicket(ticket, signature, zkProof);
        xas.mintByBridge(ticket.user, ticket.amount);

        emit InboundFinalized(ticket.user, ticket.amount, ticket.sourceChainId, _ticketId(ticket));
    }

    function outboundBurn(BridgeTicket calldata ticket, bytes calldata signature, bytes calldata zkProof) external {
        require(ticket.direction == Direction.Outbound, "BRIDGE: BAD_DIRECTION");
        require(ticket.sourceChainId == block.chainid, "BRIDGE: WRONG_SOURCE");
        require(ticket.user == msg.sender, "BRIDGE: USER_MISMATCH");

        _validateTicket(ticket, signature, zkProof);
        xas.burnByBridge(ticket.user, ticket.amount);

        emit OutboundFinalized(ticket.user, ticket.amount, ticket.targetChainId, _ticketId(ticket));
    }


    function eip712DomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function _validateTicket(BridgeTicket calldata ticket, bytes calldata signature, bytes calldata zkProof) internal {
        require(ticket.user != address(0), "BRIDGE: ZERO_USER");
        require(ticket.amount > 0, "BRIDGE: ZERO_AMOUNT");
        require(block.timestamp <= ticket.deadline, "BRIDGE: EXPIRED");
        require(ticket.nonce == nonces[ticket.user], "BRIDGE: BAD_NONCE");

        bytes32 opId = _ticketId(ticket);
        require(!consumed[opId], "BRIDGE: CONSUMED");

        _verifyEcdsa(ticket, signature);
        _verifyZk(ticket, zkProof);

        nonces[ticket.user] = ticket.nonce + 1;
        consumed[opId] = true;
    }

    function _verifyEcdsa(BridgeTicket calldata ticket, bytes calldata signature) internal view {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TICKET_TYPEHASH,
                    ticket.user,
                    ticket.amount,
                    ticket.sourceChainId,
                    ticket.targetChainId,
                    ticket.nonce,
                    ticket.deadline,
                    ticket.refId,
                    ticket.direction
                )
            )
        );

        address recovered = ECDSA.recover(digest, signature);
        require(recovered == signer, "BRIDGE: BAD_SIG");
    }

    function _verifyZk(BridgeTicket calldata ticket, bytes calldata zkProof) internal view {
        address verifier = verifierRegistry.resolveActiveVerifier(ticket.sourceChainId);
        require(verifier != address(0), "BRIDGE: NO_VERIFIER");

        bytes memory context = abi.encode(
            ticket.user,
            ticket.amount,
            ticket.sourceChainId,
            ticket.targetChainId,
            ticket.nonce,
            ticket.deadline,
            ticket.refId,
            ticket.direction,
            address(this),
            block.chainid
        );

        bool ok = IAoxconZkVerifier(verifier).verify(zkProof, context);
        require(ok, "BRIDGE: BAD_ZK");
    }

    function _ticketId(BridgeTicket calldata ticket) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ticket.user,
                ticket.amount,
                ticket.sourceChainId,
                ticket.targetChainId,
                ticket.nonce,
                ticket.deadline,
                ticket.refId,
                ticket.direction
            )
        );
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
