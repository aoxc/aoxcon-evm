// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "aoxc-v2/interfaces/IAoxcCore.sol";

contract MockCore is IAoxcCore {
    mapping(address => bool) public restricted;
    bool public coreLocked;
    string public lastAction;

    // SENTINEL BURAYI CAGIRIYOR (Risk > Threshold ise)
    function triggerEmergencyRepair(bytes4 selector, address target, string calldata reason) external {
        lastAction = string(abi.encodePacked("REPAIR: ", reason));
        coreLocked = true;
        // KRITIK: Saldirganin kapisini burada muhurle!
        restricted[target] = true; 
    }

    function setRestrictionStatus(address account, bool status, string calldata reason) external {
        restricted[account] = status;
        lastAction = string(abi.encodePacked("RESTRICT: ", reason));
    }

    function isRestricted(address account) external view returns (bool) { return restricted[account]; }
    function isCoreLocked() external view returns (bool) { return coreLocked; }

    // --- Bos Interface Fonksiyonlari (Derleme icin sart) ---
    function totalSupply() external view returns (uint256) { return 0; }
    function balanceOf(address) external view returns (uint256) { return 0; }
    function executeNeuralAction(NeuralPacket calldata) external returns (bool) { return true; }
    function clock() external view returns (uint48) { return uint48(block.timestamp); }
    function CLOCK_MODE() external view returns (string memory) { return "mode=timestamp"; }
    function getVotes(address) external view returns (uint256) { return 0; }
    function delegates(address) external view returns (address) { return address(0); }
    function delegate(address) external {}
    function getAiStatus() external view returns (bool, uint256) { return (true, 200); }
    function mint(address, uint256) external {}
    function burn(address, uint256) external {}
    function getReputationMatrix(address) external view returns (uint256) { return 0; }
}
