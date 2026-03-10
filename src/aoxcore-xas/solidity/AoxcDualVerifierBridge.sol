// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IProofVerifier {
    function verify(bytes32 digest, bytes calldata proof) external view returns (bool);
}

/// @title AoxcDualVerifierBridge
/// @notice Enforces finality window + signer approval + pluggable proof verification.
contract AoxcDualVerifierBridge {
    struct Packet {
        address origin;
        uint64 nonce;
        uint64 deadline;
        uint64 sourceTimestamp;
        uint64 sourceChainId;
        bytes32 payloadHash;
        bytes32 commandId;
        bytes signature;
        bytes proof;
        address signer;
    }

    address public owner;
    uint64 public finalityBuffer = 120;

    mapping(address => bool) public approvedSigner;
    mapping(bytes32 => bool) public consumed;
    mapping(address => uint64) public nextNonce;
    mapping(uint64 => address) public verifierForChain;

    event SignerSet(address indexed signer, bool allowed);
    event FinalityBufferSet(uint64 secondsBuffer);
    event VerifierSet(uint64 indexed chainId, address indexed verifier);
    event PacketConsumed(bytes32 indexed commandId, address indexed origin, uint64 nonce);

    error Unauthorized();
    error DeadlineExpired();
    error FinalityPending();
    error NonceMismatch();
    error Replay();
    error SignerNotApproved();
    error InvalidProof();

    constructor(address initialOwner) {
        owner = initialOwner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    function setSigner(address signer, bool allowed) external onlyOwner {
        approvedSigner[signer] = allowed;
        emit SignerSet(signer, allowed);
    }

    function setFinalityBuffer(uint64 secondsBuffer) external onlyOwner {
        finalityBuffer = secondsBuffer;
        emit FinalityBufferSet(secondsBuffer);
    }

    function setVerifier(uint64 chainId, address verifier) external onlyOwner {
        verifierForChain[chainId] = verifier;
        emit VerifierSet(chainId, verifier);
    }

    function verifyAndConsume(Packet calldata packet) external {
        if (packet.deadline < block.timestamp) revert DeadlineExpired();
        if (block.timestamp < packet.sourceTimestamp + finalityBuffer) revert FinalityPending();
        if (consumed[packet.commandId]) revert Replay();
        if (!approvedSigner[packet.signer]) revert SignerNotApproved();
        if (packet.nonce != nextNonce[packet.origin]) revert NonceMismatch();

        address verifier = verifierForChain[packet.sourceChainId];
        bytes32 digest = keccak256(
            abi.encode(
                packet.origin,
                packet.nonce,
                packet.deadline,
                packet.sourceTimestamp,
                packet.sourceChainId,
                packet.payloadHash,
                packet.commandId,
                packet.signature,
                packet.signer
            )
        );

        if (verifier != address(0)) {
            bool ok = IProofVerifier(verifier).verify(digest, packet.proof);
            if (!ok) revert InvalidProof();
        }

        consumed[packet.commandId] = true;
        unchecked {
            nextNonce[packet.origin] = packet.nonce + 1;
        }

        emit PacketConsumed(packet.commandId, packet.origin, packet.nonce);
    }
}
