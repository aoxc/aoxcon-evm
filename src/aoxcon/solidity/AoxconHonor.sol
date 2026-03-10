// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/// @title AoxconHonor
/// @notice V1 Legacy hak sahipleri için transfer edilemez makam nişanı.
contract AoxconHonor is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant ROOT_MANAGER_ROLE = keccak256("ROOT_MANAGER_ROLE");

    uint256 public constant BPS_DENOMINATOR = 10_000;

    bytes32 public merkleRoot;
    bool public claimFrozen;

    mapping(address => bool) public claimed;

    event MerkleRootUpdated(bytes32 indexed newRoot);
    event ClaimFrozen(bool indexed frozen);
    event HonorClaimed(address indexed account, uint256 v1Balance, uint256 multiplierBps, uint256 mintedAmount);

    constructor(address admin, bytes32 initialRoot) ERC20("AOXCON Honor", "hAOX") {
        require(admin != address(0), "HONOR: ZERO_ADMIN");
        require(initialRoot != bytes32(0), "HONOR: ZERO_ROOT");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ROOT_MANAGER_ROLE, admin);

        merkleRoot = initialRoot;
        emit MerkleRootUpdated(initialRoot);
    }

    function setMerkleRoot(bytes32 newRoot) external onlyRole(ROOT_MANAGER_ROLE) {
        require(!claimFrozen, "HONOR: FROZEN");
        require(newRoot != bytes32(0), "HONOR: ZERO_ROOT");
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function setClaimFrozen(bool frozen) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimFrozen = frozen;
        emit ClaimFrozen(frozen);
    }

    function claim(uint256 v1Balance, uint256 multiplierBps, bytes32[] calldata proof) external {
        require(!claimFrozen, "HONOR: FROZEN");
        require(!claimed[msg.sender], "HONOR: ALREADY");
        require(multiplierBps > 0, "HONOR: ZERO_MULTIPLIER");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, v1Balance, multiplierBps))));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "HONOR: BAD_PROOF");

        claimed[msg.sender] = true;
        uint256 mintAmount = (v1Balance * multiplierBps) / BPS_DENOMINATOR;
        _mint(msg.sender, mintAmount);

        emit HonorClaimed(msg.sender, v1Balance, multiplierBps, mintAmount);
    }

    /// @dev Non-transferable: sadece mint (from=0) ve burn (to=0) izinli.
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) revert("HONOR: NON_TRANSFERABLE");
        super._update(from, to, value);
    }
}
