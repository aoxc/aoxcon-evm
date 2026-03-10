// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

interface IAoxconZkVerifier {
    function verify(bytes calldata zkProof, bytes calldata context) external view returns (bool);
}

/// @title AoxconVerifierRegistry
/// @notice ZK verifier adreslerini zincir bazlı tak-çıkar modelde tutar.
contract AoxconVerifierRegistry is AccessControl {
    bytes32 public constant VERIFIER_ADMIN_ROLE = keccak256("VERIFIER_ADMIN_ROLE");

    mapping(uint256 => address) public verifierOfChain;

    event VerifierUpdated(uint256 indexed chainId, address indexed verifier);

    constructor(address admin) {
        require(admin != address(0), "REGISTRY: ZERO_ADMIN");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VERIFIER_ADMIN_ROLE, admin);
    }

    function setVerifier(uint256 chainId, address verifier) external onlyRole(VERIFIER_ADMIN_ROLE) {
        require(chainId != 0, "REGISTRY: ZERO_CHAIN");
        require(verifier != address(0), "REGISTRY: ZERO_VERIFIER");
        verifierOfChain[chainId] = verifier;
        emit VerifierUpdated(chainId, verifier);
    }

    function getVerifier(uint256 chainId) external view returns (address) {
        return verifierOfChain[chainId];
    }
}
