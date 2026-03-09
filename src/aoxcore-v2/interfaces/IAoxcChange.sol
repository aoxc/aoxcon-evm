// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcChange
 * @author AoxcAN AI Architect
 * @notice Autonomous Exchange & Market Defense Engine.
 * @dev V3.0: Integrated with the 10-Point Neural Handshake for Petrified Liquidity and Floor Protection.
 */
interface IAoxcChange {
    struct MarketMetrics {
        uint256 floorPrice; // Rule 3: Price baseline supported by AoxcVault
        uint256 totalPetrified; // Rule 1: Permanently locked Protocol-Owned Liquidity (POL)
        bool selfHealingActive; // Rule 8: Autonomous defense status
    }

    /*//////////////////////////////////////////////////////////////
                            TELEMETRY (EVENTS)
    //////////////////////////////////////////////////////////////*/

    event AutonomicDefenseTriggered(uint256 currentPrice, uint256 injectionAmount, uint8 riskScore);
    event FloorPriceUpdated(uint256 newFloor, uint256 nonce);
    event LiquidityPetrified(address indexed sender, uint256 amount, uint16 reasonCode);
    event NeuralSwapExecuted(address indexed actor, uint256 amountIn, uint8 riskScore);

    /*//////////////////////////////////////////////////////////////
                        CORE NEURAL OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 1, 3, 7 & 10: Executes an exchange with Mandatory Neural Risk Vetting.
     * @dev Blocks predatory MEV via 10-point handshake verification.
     * @param amountIn Amount of tokens to swap.
     * @param tokenIn Source token address.
     * @param tokenOut Destination token address.
     * @param packet The 10-point handshake proof from the Neural Sentinel.
     */
    function executeSwap(uint256 amountIn, address tokenIn, address tokenOut, IAoxcCore.NeuralPacket calldata packet)
        external;

    /**
     * @notice Rule 4 & 6: Petrifies liquidity to strengthen the market floor.
     * @dev Irreversibly converts LP tokens into Protocol-Owned Liquidity (POL).
     * @param lpToken The address of the liquidity provider pair.
     * @param amount The amount of LP tokens to lock forever.
     * @param packet The 10-point handshake verifying the petrification intent.
     */
    function petrifyLiquidity(address lpToken, uint256 amount, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 8 & 10: Triggers the Autonomic Defense mechanism to stabilize price.
     * @dev Executes buy-backs via AoxcVault if a Floor Price breach is detected.
     * @param stableToken The currency used for defense injection (e.g., USDT).
     * @param packet Evidence of market anomaly signed by the AI Node (10-Point Handshake).
     */
    function triggerAutonomicDefense(address stableToken, IAoxcCore.NeuralPacket calldata packet) external;

    /*//////////////////////////////////////////////////////////////
                            DEFENSIVE VIEWS
    //////////////////////////////////////////////////////////////*/

    function getMarketMetrics() external view returns (MarketMetrics memory);
    function getPriceOracle() external view returns (address);
    function getExchangeLockState() external view returns (bool isLocked, uint256 expiry);

    /*//////////////////////////////////////////////////////////////
                        STRATEGY & EVOLUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Rule 9: Updates the absolute floor price.
     * @param _newFloor The new price baseline in 18 decimals.
     * @param packet Handshake confirming governance approval for floor adjustment.
     */
    function setFloorPrice(uint256 _newFloor, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 10: Links an external strategy for automated market defense.
     */
    function linkStrategy(bytes32 key, address target, IAoxcCore.NeuralPacket calldata packet) external;

    /**
     * @notice Rule 8: Enables or disables the autonomous self-healing protocol.
     */
    function toggleSelfHealing(bool status, IAoxcCore.NeuralPacket calldata packet) external;
}
