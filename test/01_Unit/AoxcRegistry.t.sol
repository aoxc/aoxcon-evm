// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "aoxc-v2/core/AoxcRegistry.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";
import "aoxc-v2/libraries/AoxcErrors.sol";
import "aoxc-v2/libraries/AoxcEvents.sol";
import {IAoxcStorage} from "aoxc-interfaces/IAoxcStorage.sol";

/**
 * @title AoxcRegistryTest
 * @dev AOXC Registry Birim Testi - Tüm Event ve Storage çakışmaları giderildi.
 */
contract AoxcRegistryTest is Test {
    AoxcRegistry public registry;
    
    // Test Aktörleri
    address public admin = makeAddr("admin");
    address public citizenX = makeAddr("citizenX");
    address public intruder = makeAddr("intruder");

    function setUp() public {
        // 1. Implementation deploy
        AoxcRegistry implementation = new AoxcRegistry();
        
        // 2. Proxy üzerinden initialization (InvalidInitialization hatasını önler)
        bytes memory initData = abi.encodeWithSelector(
            AoxcRegistry.initializeRegistryV2.selector,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        registry = AoxcRegistry(address(proxy));
    }

    /*//////////////////////////////////////////////////////////////
                           INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    function test_v2_Initialization_State() public view {
        assertTrue(registry.hasRole(0x00, admin), "Admin rolu eksik");
        assertTrue(registry.hasRole(AoxcConstants.GOVERNANCE_ROLE, admin), "Gov rolu eksik");
        assertEq(registry.totalCells(), 1, "Ilk hucre olusmali");
    }

    function test_Revert_If_Initialize_Twice() public {
        vm.expectRevert(); 
        registry.initializeRegistryV2(admin);
    }

    /*//////////////////////////////////////////////////////////////
                           ONBOARDING
    //////////////////////////////////////////////////////////////*/

    function test_Onboard_New_Member() public {
        vm.startPrank(admin);
        
        // KRITIK: AoxcEvents.MemberOnboarded -> indexed(member), indexed(cellId), uint8(riskScore)
        // Topic 1 (member): true | Topic 2 (cellId): true | Topic 3 (Yok): false | Data (riskScore): true
        vm.expectEmit(true, true, false, true);
        emit AoxcEvents.MemberOnboarded(citizenX, 1, uint8(0)); 
        
        registry.onboardMember(citizenX);
        vm.stopPrank();

        assertTrue(registry.isCitizen(citizenX));
        assertEq(registry.getUserCell(citizenX), 1);
        
        IAoxcStorage.CitizenRecord memory record = registry.getCitizenRecord(citizenX);
        assertEq(record.reputation, 500);
    }

    function test_Revert_Onboard_By_NonAdmin() public {
        vm.startPrank(intruder);
        vm.expectRevert(); 
        registry.onboardMember(citizenX);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           REPUTATION & QUARANTINE
    //////////////////////////////////////////////////////////////*/

    function test_Reputation_Quarantine_Flow() public {
        vm.startPrank(admin);
        registry.onboardMember(citizenX);

        // Karantina Testi (500 -> 150)
        // AoxcEvents.BlacklistUpdated -> indexed(target), indexed(status), string(reason)
        vm.expectEmit(true, true, false, true);
        emit AoxcEvents.BlacklistUpdated(citizenX, true, "LOW_REPUTATION");

        registry.adjustReputation(citizenX, -350, 101);
        
        IAoxcStorage.CitizenRecord memory record = registry.getCitizenRecord(citizenX);
        assertTrue(record.isBlacklisted, "Karantina aktif olmali");
        assertEq(record.blacklistReason, "QUARANTINE_REPUTATION_FAILURE");
        
        // Kurtarma Testi (150 -> 500)
        registry.adjustReputation(citizenX, 350, 202);
        record = registry.getCitizenRecord(citizenX);
        assertFalse(record.isBlacklisted, "Karantina kalkmali");
        
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                           CELL DYNAMICS
    //////////////////////////////////////////////////////////////*/

    function test_Cell_Spawning_Logic() public {
        vm.startPrank(admin);
        
        uint256 maxMembers = AoxcConstants.MAX_CELL_MEMBERS;
        
        // Mevcut hucreyi (Cell 1) dolduruyoruz
        for(uint256 i = 0; i < maxMembers; i++) {
            // forge-lint: disable-next-line(unsafe-typecast)
            // casting to uint160 is safe because loop index is tiny and deterministic in tests
            registry.onboardMember(address(uint160(i + 1000)));
        }
        
        // Bu kayit Cell 2'yi tetiklemeli
        registry.onboardMember(citizenX);
        
        assertEq(registry.totalCells(), 2, "Cell 2 olusmali");
        assertEq(registry.getUserCell(citizenX), 2, "CitizenX Cell 2'de olmali");
        
        vm.stopPrank();
    }
}
