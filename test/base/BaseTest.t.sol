// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import "aoxc/core/AoxcCore.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockSurgicalInfras} from "../mocks/MockSurgicalInfras.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol"; // Yol düzeltildi: aox-libraries -> aoxc-libraries

abstract contract BaseTest is Test {
    AoxcCore public core;
    MockSurgicalInfras public mockInfra;

    address public admin = makeAddr("ADMIN");
    address public nexus = makeAddr("NEXUS_HUB");
    address public sentinel = makeAddr("SENTINEL_AI");
    address public userA = makeAddr("USER_A");
    address public userB = makeAddr("USER_B");

    function setUp() public virtual {
        vm.startPrank(admin);

        mockInfra = new MockSurgicalInfras();
        AoxcCore impl = new AoxcCore();

        // 1. ADIM: Ana başlatıcıyı (v1/v2 hybrid) çağırıyoruz
        // Parametreler: (nexus, sentinel, repair, admin, v1DailyLimit)
        bytes memory init =
            abi.encodeCall(AoxcCore.initializeAkdeniz, (nexus, sentinel, address(mockInfra), admin, 1_000_000 * 1e18));

        core = AoxcCore(payable(address(new ERC1967Proxy(address(impl), init))));

        // 2. ADIM: V2 Master modlarını aktif et (Parametresiz reinitializer)
        core.initializeV2();

        // Rollere initializeAkdeniz içinde zaten sahip olduk ama manuel mühürleme iyidir
        core.grantRole(AoxcConstants.SENTINEL_ROLE, sentinel);
        core.grantRole(AoxcConstants.GOVERNANCE_ROLE, nexus);

        vm.stopPrank();
    }
}
