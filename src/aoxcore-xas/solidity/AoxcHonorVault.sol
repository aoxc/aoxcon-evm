// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title AoxcHonorVault
/// @notice Founder reward vault for legacy v1 honor members.
contract AoxcHonorVault {
    address public owner;

    mapping(address => bool) public isFounder;
    mapping(address => uint256) public founderWeight;

    uint256 public totalFounderWeight;
    uint256 public cumulativeRewardPerWeightX18;
    mapping(address => uint256) public rewardDebtX18;

    event FounderUpdated(address indexed account, bool enabled, uint256 weight);
    event RewardsDeposited(uint256 amount, uint256 cumulativeRewardPerWeightX18);
    event Claimed(address indexed founder, uint256 amount);

    error Unauthorized();
    error InvalidFounder();
    error InvalidWeight();
    error NotFounder();
    error NothingToClaim();

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

    function setFounder(address account, bool enabled, uint256 weight) external onlyOwner {
        if (account == address(0)) revert InvalidFounder();
        if (enabled && weight == 0) revert InvalidWeight();

        _syncFounderDebt(account);

        if (isFounder[account]) {
            totalFounderWeight -= founderWeight[account];
        }

        isFounder[account] = enabled;
        founderWeight[account] = enabled ? weight : 0;
        totalFounderWeight += founderWeight[account];

        emit FounderUpdated(account, enabled, founderWeight[account]);
    }

    function depositRewards() external payable {
        if (totalFounderWeight == 0 || msg.value == 0) return;
        cumulativeRewardPerWeightX18 += (msg.value * 1e18) / totalFounderWeight;
        emit RewardsDeposited(msg.value, cumulativeRewardPerWeightX18);
    }

    function claimable(address founder) public view returns (uint256) {
        if (!isFounder[founder]) return 0;

        uint256 accruedX18 = founderWeight[founder] * cumulativeRewardPerWeightX18;
        uint256 debt = rewardDebtX18[founder];
        if (accruedX18 <= debt) return 0;
        return (accruedX18 - debt) / 1e18;
    }

    function claim() external {
        if (!isFounder[msg.sender]) revert NotFounder();

        uint256 amount = claimable(msg.sender);
        if (amount == 0) revert NothingToClaim();

        rewardDebtX18[msg.sender] = founderWeight[msg.sender] * cumulativeRewardPerWeightX18;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "TRANSFER_FAILED");

        emit Claimed(msg.sender, amount);
    }

    function _syncFounderDebt(address account) internal {
        if (!isFounder[account]) return;
        rewardDebtX18[account] = founderWeight[account] * cumulativeRewardPerWeightX18;
    }
}
