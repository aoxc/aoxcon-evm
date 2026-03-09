// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "aoxc-v1/AOXC.sol";
import "aoxc-v2/core/AoxcCore.sol";

contract V1V2ParityTest is Test {
    AOXC internal v1;
    AoxcCore internal v2;

    address internal governor = makeAddr("governor");
    address internal nexus = makeAddr("nexus");
    address internal sentinel = makeAddr("sentinel");
    address internal user = makeAddr("user");
    address internal recipient = makeAddr("recipient");

    bytes32 internal integrityHash = keccak256("AOXC_V2_PARITY_GENESIS");

    function setUp() public {
        AOXC v1Impl = new AOXC();
        bytes memory v1Init = abi.encodeWithSelector(AOXC.initialize.selector, governor);
        v1 = AOXC(address(new ERC1967Proxy(address(v1Impl), v1Init)));

        AoxcCore v2Impl = new AoxcCore();
        bytes memory v2Init = abi.encodeWithSelector(
            AoxcCore.initializeV2.selector,
            address(0),
            nexus,
            sentinel,
            address(0),
            governor,
            integrityHash
        );
        v2 = AoxcCore(address(new ERC1967Proxy(address(v2Impl), v2Init)));

        vm.prank(nexus);
        v2.mint(user, 10_000 ether);

        vm.prank(governor);
        v1.mint(user, 10_000 ether);
    }

    function test_Parity_BlacklistRecipientBlocksTransfer() public {
        vm.prank(governor);
        v1.addToBlacklist(recipient, "NO_RECEIVE");

        vm.prank(sentinel);
        v2.setRestrictionStatus(recipient, true, "NO_RECEIVE");

        vm.expectRevert();
        vm.prank(user);
        v1.transfer(recipient, 1 ether);

        vm.expectRevert();
        vm.prank(user);
        v2.transfer(recipient, 1 ether);
    }

    function test_Parity_MaxTransferEnforcement() public {
        vm.prank(governor);
        v1.setTransferVelocity(100 ether, 1000 ether);

        vm.prank(governor);
        v2.setTransferVelocity(100 ether, 1000 ether);

        vm.expectRevert();
        vm.prank(user);
        v1.transfer(recipient, 101 ether);

        vm.expectRevert();
        vm.prank(user);
        v2.transfer(recipient, 101 ether);
    }

    function test_Parity_DailyLimitEnforcement() public {
        vm.prank(governor);
        v1.setTransferVelocity(1000 ether, 200 ether);

        vm.prank(governor);
        v2.setTransferVelocity(1000 ether, 200 ether);

        vm.prank(user);
        v1.transfer(recipient, 150 ether);

        vm.prank(user);
        v2.transfer(recipient, 150 ether);

        vm.expectRevert();
        vm.prank(user);
        v1.transfer(recipient, 60 ether);

        vm.expectRevert();
        vm.prank(user);
        v2.transfer(recipient, 60 ether);
    }

    function test_Parity_PauseSemantics() public {
        vm.prank(governor);
        v1.pause();

        vm.prank(sentinel);
        v2.pause();

        vm.expectRevert();
        vm.prank(user);
        v1.transfer(recipient, 1 ether);

        vm.expectRevert();
        vm.prank(user);
        v2.transfer(recipient, 1 ether);

        vm.prank(governor);
        v1.unpause();

        vm.prank(sentinel);
        v2.unpause();

        vm.prank(user);
        v1.transfer(recipient, 1 ether);

        vm.prank(user);
        v2.transfer(recipient, 1 ether);
    }
}
