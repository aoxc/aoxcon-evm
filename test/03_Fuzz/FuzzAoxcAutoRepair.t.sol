// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import "aoxc/infra/AoxcAutoRepair.sol";
import "aoxc/libraries/AoxcConstants.sol";
import "aoxc/libraries/AoxcErrors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title Fuzz_REPAIR
 * @notice Automated maintenance and quarantine logic tests for X Layer.
 */
contract Fuzz_REPAIR is Test {
    AoxcAutoRepair repair;

    address admin = makeAddr("ADMIN");
    address nexus = makeAddr("NEXUS_HUB");
    address aiNode = makeAddr("AI_NODE");
    address auditVoice = makeAddr("AUDIT_VOICE");

    function setUp() public {
        AoxcAutoRepair repairImplementation = new AoxcAutoRepair();

        // FIX: initialize fonksiyonu v2 mimarisinde 4-5 parametre alabilir.
        // Kontratındaki tanıma göre kontrol et.
        bytes memory initData = abi.encodeCall(AoxcAutoRepair.initialize, (admin, nexus, aiNode, auditVoice));

        ERC1967Proxy proxy = new ERC1967Proxy(address(repairImplementation), initData);
        repair = AoxcAutoRepair(address(proxy));
    }

    /**
     * @notice TEST: Unauthorized Quarantine
     * FIX: Hata ismi Aoxc_Neural_IdentityForgery olarak güncellendi.
     */
    function testFuzz_Unauthorized_Quarantine(address attacker, bytes4 selector, address target) public {
        vm.assume(attacker != aiNode && attacker != admin && attacker != address(0));
        vm.assume(target != address(0));

        vm.prank(attacker);
        // Selector isimlendirmesi Core ile senkronize edildi
        vm.expectRevert(AoxcErrors.Aoxc_Neural_IdentityForgery.selector);
        repair.triggerEmergencyQuarantine(selector, target);
    }

    /**
     * @notice TEST: Reserved Selectors Immunity
     * FIX: AOXC_CustomRevert -> Aoxc_CustomRevert
     */
    function testFuzz_Reserved_Selectors_Immunity(uint8 choice) public {
        bytes4 selector;
        if (choice % 4 == 0) selector = repair.triggerEmergencyQuarantine.selector;
        else if (choice % 4 == 1) selector = repair.liftQuarantine.selector;
        else if (choice % 4 == 2) selector = repair.executePatch.selector;
        else selector = 0x3659cfe6; // upgradeToAndCall selector (v5 format)

        vm.prank(aiNode);
        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_CustomRevert.selector, "REPAIR: RESERVED"));
        repair.triggerEmergencyQuarantine(selector, address(0x123));
    }

    /**
     * @notice TEST: Quarantine Execution Check
     */
    function testFuzz_Quarantine_Execution_Check(bytes4 selector, address mockTarget) public {
        vm.assume(mockTarget != address(0) && mockTarget != address(repair));
        // Rezervli fonksiyonları karantinaya alamazsın (Immunity check)
        vm.assume(!repair.isReserved(selector));

        // 1. AI Node karantinayı tetikler
        vm.prank(aiNode);
        repair.triggerEmergencyQuarantine(selector, mockTarget);

        // 2. Kontrol: mockTarget için bu selector artık kapalı olmalı
        vm.prank(mockTarget);
        bool operational = repair.isOperational(selector);

        assertEq(operational, false, "INVARIANT: Quarantined function must NOT be operational");
    }

    /**
     * @notice TEST: Auto-Unlock Mechanism
     */
    function testFuzz_Auto_Unlock_Mechanism(bytes4 selector, address mockTarget, uint256 skipTime) public {
        vm.assume(mockTarget != address(0) && !repair.isReserved(selector));

        // Max freeze süresinden sonrasını test et (Örn: 24 saat)
        skipTime = bound(skipTime, AoxcConstants.AI_MAX_FREEZE_DURATION + 1, 365 days);

        vm.prank(aiNode);
        repair.triggerEmergencyQuarantine(selector, mockTarget);

        // Zamanı ileri sar
        skip(skipTime);

        vm.prank(mockTarget);
        bool operational = repair.isOperational(selector);

        assertEq(operational, true, "INVARIANT: Quarantine must expire automatically");
    }
}
