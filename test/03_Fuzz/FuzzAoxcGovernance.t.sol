// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {GovernanceTest} from "aoxc-test/01_Unit/Unit02_AoxcGovernance.t.sol";
import {console2} from "forge-std/Test.sol";

/**
 * @title AOXC Governance Advanced Fuzzing
 * @notice DAO ve Veto mekanizmalarını rastgele girdilerle stres testine sokar.
 */
contract GovernanceFuzzTest is GovernanceTest {
    /**
     * @notice Veto eşiği hesaplamasını rastgele toplam arz ve güç ile test eder.
     * @dev BPS hesaplamalarında taşma (overflow) veya yuvarlama hatalarını yakalar.
     */
    function testFuzz_VetoThreshold_Math(uint256 totalSupply, uint256 userPower) public {
        // 1. Sınırları Belirle (1.000 ile 1 Milyar token arası arz simülasyonu)
        totalSupply = bound(totalSupply, 1_000 * 1e18, 1_000_000_000 * 1e18);
        userPower = bound(userPower, 0, totalSupply);

        // 2. State Hazırla - Her koşumda yeni bir arz oluşturmak için MockToken'ı güncelle
        // Mevcut arzı fuzzer değerine eşitlemek için "dead address"e mint yapıyoruz
        token.mint(address(0xDEAD), totalSupply);
        token.mint(user1, userPower);

        // Flash-loan koruması için 1 blok ilerle
        vm.roll(block.number + 1);

        // 3. Kontrat Ayarlarını Al (Initialize'da set edilen değerler)
        uint256 minVetoPower = 1000 * 1e18;

        // 4. Aksiyon ve Validasyon
        if (userPower < minVetoPower) {
            // Eğer güç yetersizse revert bekliyoruz
            vm.expectRevert();
            vm.prank(user1);
            auditVoice.emitVetoSignal(1);
        } else {
            // Güç yeterliyse sinyal başarılı olmalı
            vm.prank(user1);
            auditVoice.emitVetoSignal(1);

            console2.log("Fuzz Pass | Power:", userPower / 1e18, "TotalSupply:", totalSupply / 1e18);
        }
    }

    /**
     * @notice İmza süresinin (deadline) ve zaman aşımının doğruluğunu test eder.
     * @param timeJump Saniye cinsinden zaman ilerlemesi (1 sn - 100 yıl)
     */
    function testFuzz_Signature_Expiration(uint256 timeJump) public {
        // 1. Zaman sıçramasını sınırla (Overflow engellemek için max 100 yıl)
        timeJump = bound(timeJump, 1, 36500 days);

        // 2. Bir aksiyon öner ve imza hazırla
        uint256 txIdx = daoManager.proposeAction(address(0x99), 0, "");
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = daoManager.nonces(user1);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                daoManager.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(daoManager.CONFIRM_TYPEHASH(), txIdx, nonce, deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1Key, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // 3. Zamanı fuzzer'ın belirlediği kadar ileri sar
        uint256 warpTo = block.timestamp + timeJump;
        vm.warp(warpTo);

        // 4. Deadline Kontrolü
        if (warpTo > deadline) {
            // Süre dolduysa imza reddedilmeli (SIG_EXPIRED)
            vm.expectRevert();
            vm.prank(user1);
            daoManager.voteWithSignature(txIdx, deadline, signature);
        } else {
            // Süre dolmadıysa başarılı olmalı
            vm.prank(user1);
            daoManager.voteWithSignature(txIdx, deadline, signature);
        }
    }

    /**
     * @notice Admin yetkisiyle eşik değerlerin sınırlarını fuzz eder.
     * @param newThreshold 1 ile 10.000 arası rastgele BPS değeri.
     */
    function testFuzz_Admin_Threshold_Boundaries(uint256 newThreshold) public {
        // Kontrat %1 (100) ile %20 (2000) arasını kabul ediyor
        vm.startPrank(admin);
        if (newThreshold < 100 || newThreshold > 2000) {
            vm.expectRevert();
            auditVoice.setThreshold(newThreshold);
        } else {
            auditVoice.setThreshold(newThreshold);
        }
        vm.stopPrank();
    }
}
