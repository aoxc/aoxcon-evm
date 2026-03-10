// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title AOXC-XAS lightweight omnichain token core
/// @notice Minimal mint/burn gate with idempotent bridge message accounting.
contract AoxcXasToken {
    string public constant name = "AOXC-XAS";
    string public constant symbol = "XAS";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    address public owner;
    mapping(address => bool) public bridgeOperators;
    mapping(bytes32 => bool) public consumedMessage;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event BridgeOperatorSet(address indexed operator, bool allowed);
    event BridgeMint(bytes32 indexed messageId, address indexed to, uint256 amount);
    event BridgeBurn(bytes32 indexed messageId, address indexed from, uint256 amount);

    error Unauthorized();
    error MessageAlreadyConsumed();
    error ZeroAddress();
    error InsufficientBalance();

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (!bridgeOperators[msg.sender]) revert Unauthorized();
        _;
    }

    function setBridgeOperator(address operator, bool allowed) external onlyOwner {
        bridgeOperators[operator] = allowed;
        emit BridgeOperatorSet(operator, allowed);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function bridgeMint(bytes32 messageId, address to, uint256 amount) external onlyOperator {
        if (consumedMessage[messageId]) revert MessageAlreadyConsumed();
        consumedMessage[messageId] = true;

        totalSupply += amount;
        balanceOf[to] += amount;

        emit BridgeMint(messageId, to, amount);
        emit Transfer(address(0), to, amount);
    }

    function bridgeBurn(bytes32 messageId, address from, uint256 amount) external onlyOperator {
        if (consumedMessage[messageId]) revert MessageAlreadyConsumed();
        consumedMessage[messageId] = true;

        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] = balance - amount;
            totalSupply -= amount;
        }

        emit BridgeBurn(messageId, from, amount);
        emit Transfer(from, address(0), amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = balanceOf[from];
        if (balance < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] = balance - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }
}
