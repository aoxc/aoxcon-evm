// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {AoxconXasToken} from "./AoxconXasToken.sol";
import {AoxconVerifierRegistry, IAoxconZkVerifier} from "./AoxconVerifierRegistry.sol";

/// @title AoxconBridge
/// @notice Çift doğrulamalı (ECDSA + ZK) AOXCON geçidi.
contract AoxconBridge is AccessControl {
    using ECDSA for bytes32;

    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    struct BridgeTicket {
        address user;
        uint256 amount;
        uint256 sourceChainId;
        uint256 nonce;
        uint256 deadline;
        bytes32 refId;
    }

    AoxconXasToken public immutable xas;
    AoxconVerifierRegistry public immutable verifierRegistry;

    address public signer;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => bool) public consumed;

    event SignerUpdated(address indexed signer);
    event InboundFinalized(address indexed user, uint256 amount, uint256 indexed sourceChainId, bytes32 indexed opId);
    event OutboundFinalized(address indexed user, uint256 amount, uint256 indexed targetChainId, bytes32 indexed opId);

    constructor(address admin, address xasToken, address registry, address initialSigner) {
        require(admin != address(0), "BRIDGE: ZERO_ADMIN");
        require(xasToken != address(0), "BRIDGE: ZERO_XAS");
        require(registry != address(0), "BRIDGE: ZERO_REGISTRY");
        require(initialSigner != address(0), "BRIDGE: ZERO_SIGNER");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIG_ROLE, admin);

        xas = AoxconXasToken(xasToken);
        verifierRegistry = AoxconVerifierRegistry(registry);
        signer = initialSigner;
    }

    function setSigner(address newSigner) external onlyRole(CONFIG_ROLE) {
        require(newSigner != address(0), "BRIDGE: ZERO_SIGNER");
        signer = newSigner;
        emit SignerUpdated(newSigner);
    }

    function inboundMint(BridgeTicket calldata ticket, bytes calldata signature, bytes calldata zkProof) external {
        _validateTicket(ticket, signature, zkProof);
        xas.mintByBridge(ticket.user, ticket.amount);
        emit InboundFinalized(ticket.user, ticket.amount, ticket.sourceChainId, _ticketId(ticket));
    }

    function outboundBurn(BridgeTicket calldata ticket, uint256 targetChainId, bytes calldata signature, bytes calldata zkProof)
        external
    {
        _validateTicket(ticket, signature, zkProof);
        require(ticket.user == msg.sender, "BRIDGE: USER_MISMATCH");
        xas.burnByBridge(ticket.user, ticket.amount);
        emit OutboundFinalized(ticket.user, ticket.amount, targetChainId, _ticketId(ticket));
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this)));
    }

    function _validateTicket(BridgeTicket calldata ticket, bytes calldata signature, bytes calldata zkProof) internal {
        require(ticket.user != address(0), "BRIDGE: ZERO_USER");
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
        bytes32 digest = keccak256(
            abi.encode(
                domainSeparator(),
                ticket.user,
                ticket.amount,
                ticket.sourceChainId,
                ticket.nonce,
                ticket.deadline,
                ticket.refId
            )
        );

        bytes32 ethSigned = MessageHashUtils.toEthSignedMessageHash(digest);
        address recovered = ethSigned.recover(signature);
        require(recovered == signer, "BRIDGE: BAD_SIG");
    }

    function _verifyZk(BridgeTicket calldata ticket, bytes calldata zkProof) internal view {
        address verifier = verifierRegistry.verifierOfChain(ticket.sourceChainId);
        require(verifier != address(0), "BRIDGE: NO_VERIFIER");

        bytes memory context = abi.encode(domainSeparator(), ticket.user, ticket.amount, ticket.sourceChainId, ticket.nonce, ticket.refId);
        bool ok = IAoxconZkVerifier(verifier).verify(zkProof, context);
        require(ok, "BRIDGE: BAD_ZK");
    }

    function _ticketId(BridgeTicket calldata ticket) internal pure returns (bytes32) {
        return keccak256(abi.encode(ticket.user, ticket.amount, ticket.sourceChainId, ticket.nonce, ticket.deadline, ticket.refId));
    }
}
