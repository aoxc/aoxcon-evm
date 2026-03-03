// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import "aoxc/core/AoxcCore.sol";
import "aoxc/libraries/AoxcConstants.sol";
import "aoxc/libraries/AoxcErrors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MockRepair
 * @notice System maintenance state simulator for testing.
 */
contract MockRepair {
    bool public operational = true;

    function setOperational(bool status) external {
        operational = status;
    }

    function isOperational(bytes4) external view returns (bool) {
        return operational;
    }
}

/**
 * @title MockSentinel
 * @notice Access control simulator for testing.
 */
contract MockSentinel {
    function isAllowed(address, address) external pure returns (bool) {
        return true;
    }
}

/**
 * @title Fuzz_AoxcCore
 * @notice Advanced Fuzzing Suite for Internal Logic & Invariants.
 */
contract Fuzz_AoxcCore is Test {
    AoxcCore public core;
    MockRepair public mockRepair;
    MockSentinel public mockSentinel;

    address public nexus = makeAddr("NEXUS");
    address public admin = makeAddr("ADMIN");
    address public userA = makeAddr("USER_A");
    address public userB = makeAddr("USER_B");

    function setUp() public {
        mockRepair = new MockRepair();
        mockSentinel = new MockSentinel();
        AoxcCore coreImplementation = new AoxcCore();

        // 1. ADIM: Kontratındaki orijinal fonksiyon ismini (initializeAkdeniz) kullanıyoruz
        bytes memory initData = abi.encodeCall(
            AoxcCore.initializeAkdeniz, (nexus, address(mockSentinel), address(mockRepair), admin, 1_000_000 ether)
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(coreImplementation), initData);
        core = AoxcCore(payable(address(proxy)));

        // 2. ADIM: V2 master modlarını aktif et
        core.initializeV2();

        // Fuzzing konfigürasyonu
        excludeContract(address(proxy));
        excludeContract(address(coreImplementation));
        excludeSender(address(0));

        // İlk token dağıtımı
        vm.prank(nexus);
        core.mint(admin, 1_000_000 ether);
    }

    /**
     * @notice Test Temporal Collision (Aynı blokta çift transfer koruması).
     */
    function testFuzz_Temporal_Collision_Security(uint256 amount) public {
        uint256 limit = (core.totalSupply() * AoxcConstants.MAX_TRANSFER_BPS) / AoxcConstants.BPS_DENOMINATOR;
        amount = bound(amount, 1, limit / 2);
        vm.assume(amount * 2 <= core.balanceOf(admin));

        vm.prank(admin);
        core.transfer(userA, amount * 2);

        vm.startPrank(userA);
        // İlk transfer başarılı olmalı
        core.transfer(userB, amount);

        // İkinci transfer (Aynı Blok): Revert bekliyoruz
        // Hata kütüphanendeki isme göre Aoxc_TemporalCollision olarak güncellendi
        vm.expectRevert(AoxcErrors.Aoxc_TemporalCollision.selector);
        core.transfer(userB, amount);

        vm.stopPrank();

        // Bir sonraki bloğa geç: Başarılı olmalı
        vm.warp(block.timestamp + 1);
        vm.prank(userA);
        assertTrue(core.transfer(userB, amount), "Post-warp transfer failed");
    }

    /**
     * @notice Transfer limitlerini (BPS) denetle.
     */
    function testFuzz_Transfer_Cap_Enforcement(uint256 amount) public {
        uint256 total = core.totalSupply();
        uint256 limit = (total * AoxcConstants.MAX_TRANSFER_BPS) / AoxcConstants.BPS_DENOMINATOR;

        // Limiti aşan bir miktar belirle
        amount = bound(amount, limit + 1, total);

        vm.prank(nexus);
        core.mint(admin, amount);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_ExceedsMaxTransfer.selector, amount, limit));
        core.transfer(userA, amount);
    }

    /**
     * @notice Invariant kontrolü: Bakiyeler toplam arzı geçmemeli.
     */
    function invariant_BalanceSolvency() public view {
        uint256 trackedBalance = core.balanceOf(admin) + core.balanceOf(userA) + core.balanceOf(userB);
        assertLe(trackedBalance, core.totalSupply(), "Solvency violation");
    }
}
