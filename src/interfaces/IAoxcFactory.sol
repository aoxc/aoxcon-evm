// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAoxcFactory
 * @notice Interface for the AOXCAN System Architect.
 */
interface IAoxcFactory {
    struct DeploymentSuite {
        address registry;
        address vault;
        address nexus;
        address cpex;
    }

    /**
     * @notice Deploys the V2.2 Neural Ecosystem.
     * @param aiSentinel The address of the AI Audit Voice.
     */
    function deployV2Ecosystem(address aiSentinel) external returns (DeploymentSuite memory);

    /**
     * @notice Returns the V1 Legacy addresses used as roots.
     */
    function AOXC_TOKEN_V1() external view returns (address);
    function MAIN_ADMIN_V1() external view returns (address);
    function MULTISIG_V1() external view returns (address);
}
