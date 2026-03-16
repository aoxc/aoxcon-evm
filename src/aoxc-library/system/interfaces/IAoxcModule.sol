// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Common interface for standalone AOXC library modules.
interface IAoxcModule {
    /// @notice One-time initializer called by factory after clone deployment.
    function initialize(bytes calldata initData) external;

    /// @notice Short machine-readable module type (e.g. "TOKEN", "TREASURY").
    function moduleType() external pure returns (bytes32);

    /// @notice Human-readable version string for release governance.
    function moduleVersion() external pure returns (string memory);
}
