// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BaseTest} from "../base/BaseTest.t.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol"; // Yol düzeltildi
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";

contract AoxcCore_Fuzz_Test is BaseTest {
    /**
     * @notice [FUZZ] Sentinel Enforcement & Restriction Logic
     * @dev V2.2 uyumlu: setRestrictionStatus kullanımı ve CamelCase hata seçicileri.
     */
    function testFuzz_Sentinel_Enforcement(address attacker, uint256 amount, string memory reason) public {
        // 1. Kısıtlamalar
        vm.assume(attacker != address(0));
        vm.assume(userB != address(0));
        vm.assume(attacker != userB);
        vm.assume(attacker != admin && attacker != nexus && attacker != sentinel);

        // Boş reason kontrolü
        if (bytes(reason).length == 0) reason = "Malicious Activity Detected";

        // 2. Miktarı sınırla (Anti-Whale ve Enflasyon Cap'ine takılmamak için)
        amount = bound(amount, 1, 10_000 * 1e18);

        // 3. Kullanıcıya token sağla (Nexus/Governance yetkisiyle)
        vm.prank(nexus);
        core.mint(attacker, amount);

        // 4. FIX: setBlacklist -> setRestrictionStatus (V2.2 Standartı)
        // Yetki: SENTINEL_ROLE (BaseTest'teki sentinel adresi)
        vm.prank(sentinel);
        core.setRestrictionStatus(attacker, true, reason);

        // 5. Transfer denemesi -> Hata bekliyoruz
        // FIX: AOXC_Blacklisted -> Aoxc_Blacklisted (CamelCase Senkronizasyonu)
        vm.startPrank(attacker);
        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_Blacklisted.selector, attacker, reason));

        // Transfer işlemi (Kilitli olduğu için revert etmeli)
        core.transfer(userB, amount);

        vm.stopPrank();
    }
}
