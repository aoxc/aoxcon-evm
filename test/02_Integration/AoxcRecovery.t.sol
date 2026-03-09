// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "aoxc-v2/infra/AoxcAutoRepair.sol";
import "../mocks/MockCore.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";

contract AoxcRecoveryTest is Test {
    AoxcAutoRepair public autoRepair;
    MockCore public core;

    address admin = makeAddr("AOXC_High_Command");
    address nexus = makeAddr("NEXUS_GOVERNANCE");
    address vault = makeAddr("VaultV2");
    bytes4 vaultSelector = bytes4(keccak256("withdraw(uint256)"));

    function setUp() public {
        core = new MockCore();
        AoxcAutoRepair repairImpl = new AoxcAutoRepair();
        
        // AuditVoice olarak admini atıyoruz
        autoRepair = AoxcAutoRepair(address(new ERC1967Proxy(address(repairImpl), 
            abi.encodeWithSelector(AoxcAutoRepair.initializeAutoRepairV2.selector, 
            admin, address(core), nexus, admin, admin))));
    }

    function test_Autonomous_Patch_And_Recovery_Cycle() public {
        // --- 1. ADIM: KARANTİNA (Sentinel tarafından tetiklenmiş gibi) ---
        IAoxcCore.NeuralPacket memory packet;
        packet.riskScore = AoxcConstants.NEURAL_RISK_SAFE; // Tamir işlemleri güvenli skorla yapılır
        
        vm.prank(admin);
        autoRepair.triggerEmergencyQuarantine(vaultSelector, vault, packet);
        
        vm.prank(vault);
        assertFalse(autoRepair.isOperational(vaultSelector), "Karantina basarisiz!");
        console.log(">> Durum: Vault karantinaya alindi (Locked).");

        // --- 2. ADIM: NEURAL PATCH (Yama Uygulama) ---
        uint256 anomalyId = 888;
        address newLogic = makeAddr("Fixed_Vault_Logic");

        vm.prank(nexus); // Sadece Governance (Nexus) yama yapabilir
        autoRepair.executePatch(anomalyId, vaultSelector, vault, newLogic, packet);
        
        assertTrue(autoRepair.validatePatch(anomalyId), "Yama dogrulamasi basarisiz!");
        console.log(">> Durum: Anomali %s icin Neural Patch uygulandi.", anomalyId);

        // --- 3. ADIM: LIFT QUARANTINE (Kilidi Kaldırma) ---
        vm.prank(admin); // AuditVoice veya Admin kilidi kaldirabilir
        autoRepair.liftQuarantine(vaultSelector, vault, packet);

        // --- 4. ADIM: FİNAL DOĞRULAMA ---
        vm.prank(vault);
        assertTrue(autoRepair.isOperational(vaultSelector), "Karantina kaldirilamadi!");
        console.log(">> Durum: Sistem tamir edildi ve Vault tekrar ONLINE.");
    }
}
