// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcVault
 * @author Aoxcore Security Architecture
 * @notice Autonomous Treasury and Multi-Asset Reserve Vault.
 * @dev V3.0: Protected by the 10-Point Neural Handshake for automated settlements and recovery.
 */
interface IAoxcVault {
    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event WindowOpened(uint256 indexed windowId, uint256 windowEnd, uint8 riskScore);
    event FundsWithdrawn(address indexed token, address indexed to, uint256 amount, uint256 nonce);
    event EmergencyModeToggled(bool status, uint16 reasonCode);
    event NeuralRecoveryExecuted(address indexed token, address indexed to, uint256 amount, bytes32 protocolHash);

    /*//////////////////////////////////////////////////////////////
                        TREASURY OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Accepts native assets into the autonomous reserve.
     */
    function deposit() external payable;

    /**
     * @notice Rule 3, 7 & 10: Secure ERC20 withdrawal with Neural Vetting.
     * @param packet The 10-point handshake verifying the legitimacy of the transfer.
     */
    function withdrawErc20(address token, address to, uint256 amount, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 3, 7 & 10: Secure ETH withdrawal with Neural Vetting.
     */
    function withdrawEth(address payable to, uint256 amount, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 6: Requests a settlement for RWA or trade clearing.
     */
    function requestSettlement(address token, address to, uint256 amount, IAoxcCore.NeuralPacket calldata packet)
        external;

    /**
     * @notice Rule 8: AI-triggered refill of operational hot wallets.
     */
    function requestAutomatedRefill(uint256 amount, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                        SAFETY & SELF-HEALING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 8 & 10: Emergency recovery of funds to a verified cold-storage.
     */
    function emergencyNeuralRecovery(address token, address to, uint256 amount, IAoxcCore.NeuralPacket calldata packet)
        external;

    /**
     * @notice Rule 9: Proposes a new logic for the Vault's internal accounting.
     */
    function proposeSelfHealing(address newLogic, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Finalizes the self-healing process after the cooling period.
     */
    function finalizeSelfHealing(IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 8: Forces the vault open in extreme Black Swan events.
     */
    function emergencyUnseal(IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                            ANALYTICS & VIEWS
    //////////////////////////////////////////////////////////////*/

    function openNextWindow(IAoxcCore.NeuralPacket calldata packet) external;
    function toggleEmergencyMode(bool status, IAoxcCore.NeuralPacket calldata packet) external;

    function getInitialUnlockTime() external view returns (uint256);
    function getCurrentWindowEnd() external view returns (uint256);
    function getCurrentWindowId() external view returns (uint256);
    function getRemainingLimit(address token) external view returns (uint256);
    function isVaultLocked() external view returns (bool);
    function getVaultTvl() external view returns (uint256);
}
