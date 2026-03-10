// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AoxconHonor is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ROOT_MANAGER_ROLE = keccak256("ROOT_MANAGER_ROLE");

    uint256 public constant BPS_DENOMINATOR = 10_000;

    bytes32 public merkleRoot;
    uint256 public claimStart;
    uint256 public claimEnd;
    bool public claimFrozen;

    mapping(address account => bool done) public claimed;

    event MerkleRootUpdated(bytes32 indexed newRoot);
    event ClaimWindowConfigured(uint256 start, uint256 end);
    event ClaimFrozen(bool indexed frozen);
    event HonorClaimed(address indexed account, uint256 v1Balance, uint256 multiplierBps, uint256 mintedAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, bytes32 initialRoot, uint256 start, uint256 end) external initializer {
        require(admin != address(0), "HONOR: ZERO_ADMIN");
        require(initialRoot != bytes32(0), "HONOR: ZERO_ROOT");
        require(start < end, "HONOR: BAD_WINDOW");

        __ERC20_init("AOXCON Honor", "hAOX");
        __ERC20Burnable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(ROOT_MANAGER_ROLE, admin);

        merkleRoot = initialRoot;
        claimStart = start;
        claimEnd = end;

        emit MerkleRootUpdated(initialRoot);
        emit ClaimWindowConfigured(start, end);
    }

    function setMerkleRoot(bytes32 newRoot) external onlyRole(ROOT_MANAGER_ROLE) {
        require(!claimFrozen, "HONOR: FROZEN");
        require(newRoot != bytes32(0), "HONOR: ZERO_ROOT");

        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function configureClaimWindow(uint256 start, uint256 end) external onlyRole(ROOT_MANAGER_ROLE) {
        require(!claimFrozen, "HONOR: FROZEN");
        require(start < end, "HONOR: BAD_WINDOW");

        claimStart = start;
        claimEnd = end;
        emit ClaimWindowConfigured(start, end);
    }

    function setClaimFrozen(bool frozen) external onlyRole(DEFAULT_ADMIN_ROLE) {
        claimFrozen = frozen;
        emit ClaimFrozen(frozen);
    }

    function claim(uint256 v1Balance, uint256 multiplierBps, bytes32[] calldata proof) external {
        require(!claimFrozen, "HONOR: FROZEN");
        require(block.timestamp >= claimStart, "HONOR: NOT_STARTED");
        require(block.timestamp <= claimEnd, "HONOR: ENDED");
        require(!claimed[msg.sender], "HONOR: ALREADY");
        require(multiplierBps > 0, "HONOR: ZERO_MULTIPLIER");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, v1Balance, multiplierBps))));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "HONOR: BAD_PROOF");

        claimed[msg.sender] = true;
        uint256 mintAmount = (v1Balance * multiplierBps) / BPS_DENOMINATOR;
        _mint(msg.sender, mintAmount);

        emit HonorClaimed(msg.sender, v1Balance, multiplierBps, mintAmount);
    }

    /// @dev Non-transferable: only mint and burn are allowed.
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) revert("HONOR: NON_TRANSFERABLE");
        super._update(from, to, value);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
