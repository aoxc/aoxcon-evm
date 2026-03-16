// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcModule} from "aoxc-library/system/interfaces/IAoxcModule.sol";

/// @notice Example standalone token module for external chains consuming AOXC library.
contract AoxcExampleTokenModule is IAoxcModule {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    bool public initialized;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error AlreadyInitialized();
    error Unauthorized();
    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();

    function initialize(bytes calldata initData) external override {
        if (initialized) revert AlreadyInitialized();

        (address owner_, string memory name_, string memory symbol_, uint256 supply_) =
            abi.decode(initData, (address, string, string, uint256));

        if (owner_ == address(0)) revert ZeroAddress();

        owner = owner_;
        name = name_;
        symbol = symbol_;
        initialized = true;

        if (supply_ > 0) {
            totalSupply = supply_;
            balanceOf[owner_] = supply_;
            emit Transfer(address(0), owner_, supply_);
        }
    }

    function moduleType() external pure override returns (bytes32) {
        return keccak256("TOKEN");
    }

    function moduleVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != owner) revert Unauthorized();
        if (to == address(0)) revert ZeroAddress();

        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 current = allowance[from][msg.sender];
        if (current < amount) revert InsufficientAllowance();
        allowance[from][msg.sender] = current - amount;

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance();

        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }
}
