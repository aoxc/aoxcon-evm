// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title AoxcVerifierRegistry
/// @notice Pluggable verifier adapters for chain-specific proof validation (Sui/XLayer/Ada).
contract AoxcVerifierRegistry {
    address public owner;
    mapping(uint256 => address) public verifierOf;

    event VerifierSet(uint256 indexed chainId, address indexed verifier);

    error Unauthorized();
    error InvalidVerifier();

    constructor(address initialOwner) {
        owner = initialOwner;
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert Unauthorized();
    }

    function setVerifier(uint256 chainId, address verifier) external onlyOwner {
        if (verifier == address(0)) revert InvalidVerifier();
        verifierOf[chainId] = verifier;
        emit VerifierSet(chainId, verifier);
    }
}
