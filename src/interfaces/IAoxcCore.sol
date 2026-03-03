// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IAoxcCore
 * @author Aoxcore Security Architecture
 * @notice Global Interface for the Autonomous AI-DAO Core Logic.
 */
interface IAoxcCore {
    struct NeuralPacket {
        address origin; // 1. The original EOA triggering the action
        address target; // 2. The recipient or contract being interacted with
        uint256 value; // 3. Amount of assets
        uint256 nonce; // 4. Sequential ID
        uint48 deadline; // 5. Expiration timestamp
        uint16 reasonCode; // 6. Categorized reason
        uint8 riskScore; // 7. AI-generated risk score
        bool autoRepairMode; // 8. Auto-adjust on failure
        bytes32 protocolHash; // 9. Hash of the specific protocol
        bytes neuralSignature; // 10. AI Sentinel's cryptographic seal
    }

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    function executeNeuralAction(NeuralPacket calldata packet) external returns (bool);

    function clock() external view returns (uint48);
    function CLOCK_MODE() external view returns (string memory);
    function getVotes(address account) external view returns (uint256);
    function delegates(address account) external view returns (address);
    function delegate(address delegatee) external;

    function triggerEmergencyRepair(bytes4 selector, address target, string calldata reason) external;
    function getAiStatus() external view returns (bool isActive, uint256 currentNeuralThreshold);
    function setRestrictionStatus(address account, bool status, string calldata reason) external;
    function isRestricted(address account) external view returns (bool);
    function isCoreLocked() external view returns (bool);

    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function getReputationMatrix(address account) external view returns (uint256);
}
