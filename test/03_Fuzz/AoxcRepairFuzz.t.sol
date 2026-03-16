// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AoxcAutoRepair} from "aoxc-v2/infra/AoxcAutoRepair.sol";
import {MockCore} from "../mocks/MockCore.sol";

contract AoxcRepairFuzz is Test {
    AoxcAutoRepair public autoRepair;
    MockCore public core;
    address admin = makeAddr("admin");

    function setUp() public {
        core = new MockCore();
        AoxcAutoRepair repairImpl = new AoxcAutoRepair();
        autoRepair = AoxcAutoRepair(address(new ERC1967Proxy(address(repairImpl), 
            abi.encodeWithSelector(AoxcAutoRepair.initializeAutoRepairV2.selector, 
            admin, address(core), admin, admin, admin))));
    }

    // Foundry bu fonksiyonu rastgele degerlerle binlerce kez cagiracak
    function testFuzz_Quarantine_Integrity(uint256 randomId, bytes4 selector, address target) public {
        vm.assume(target != address(0));
        vm.assume(selector != bytes4(0));
        
        IAoxcCore.NeuralPacket memory packet;
        packet.riskScore = 50;

        // Rastgele bir hedefi karantinaya al
        vm.prank(admin);
        autoRepair.triggerEmergencyQuarantine(selector, target, packet);

        // Sistemin kilitlendigini dogrula
        vm.prank(target);
        assertFalse(autoRepair.isOperational(selector));
    }
}
