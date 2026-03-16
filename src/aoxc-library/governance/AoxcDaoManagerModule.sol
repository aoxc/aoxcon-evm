// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {AoxcDaoManager} from "aoxc-gov/AoxcDaoManager.sol";

/// @notice Library entrypoint for AOXC governance consumers.
/// @dev Thin wrapper that forwards constructor args to the maintained V2 governance implementation.
contract AoxcDaoManagerModule is AoxcDaoManager {
    constructor(address registry_, address token_, uint256 lifespan_) AoxcDaoManager(registry_, token_, lifespan_) {}
}
