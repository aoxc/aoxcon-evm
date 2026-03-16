// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAoxcModule} from "aoxc-library/system/interfaces/IAoxcModule.sol";

/// @notice Example treasury module with owner-governed token/ETH release operations.
contract AoxcExampleTreasuryModule is IAoxcModule {
    using SafeERC20 for IERC20;

    address public owner;
    address public payoutOperator;
    bool public initialized;

    event OperatorUpdated(address indexed operator);
    event TokenReleased(address indexed token, address indexed to, uint256 amount);
    event EthReleased(address indexed to, uint256 amount);

    error AlreadyInitialized();
    error Unauthorized();
    error ZeroAddress();

    receive() external payable {}

    function initialize(bytes calldata initData) external override {
        if (initialized) revert AlreadyInitialized();

        (address owner_, address payoutOperator_) = abi.decode(initData, (address, address));
        if (owner_ == address(0) || payoutOperator_ == address(0)) revert ZeroAddress();

        owner = owner_;
        payoutOperator = payoutOperator_;
        initialized = true;
    }

    function moduleType() external pure override returns (bytes32) {
        return keccak256("TREASURY");
    }

    function moduleVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    function setPayoutOperator(address operator) external {
        if (msg.sender != owner) revert Unauthorized();
        if (operator == address(0)) revert ZeroAddress();

        payoutOperator = operator;
        emit OperatorUpdated(operator);
    }

    function releaseToken(address token, address to, uint256 amount) external {
        if (msg.sender != payoutOperator) revert Unauthorized();
        IERC20(token).safeTransfer(to, amount);
        emit TokenReleased(token, to, amount);
    }

    function releaseEth(address to, uint256 amount) external {
        if (msg.sender != payoutOperator) revert Unauthorized();
        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH_RELEASE_FAILED");
        emit EthReleased(to, amount);
    }
}
