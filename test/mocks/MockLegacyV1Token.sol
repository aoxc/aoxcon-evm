// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

contract MockLegacyV1Token {
    uint256 public mintCalls;
    uint256 public blacklistAddCalls;
    uint256 public blacklistRemoveCalls;

    mapping(address => bool) public blacklisted;
    mapping(address => uint256) public mintedTo;

    function mint(address to, uint256 amount) external {
        mintCalls += 1;
        mintedTo[to] += amount;
    }

    function addToBlacklist(address account, string calldata) external {
        blacklistAddCalls += 1;
        blacklisted[account] = true;
    }

    function removeFromBlacklist(address account) external {
        blacklistRemoveCalls += 1;
        blacklisted[account] = false;
    }
}
