// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "aoxc-v1/AOXC.sol";
import "aoxc-v2/core/AoxcCore.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";

contract V1ToV2MigrationUpgradeTest is Test {
    AOXC internal v1;

    address internal governor = makeAddr("governor");
    address internal nexus = makeAddr("nexus");
    address internal sentinel = makeAddr("sentinel");
    address internal user = makeAddr("user");

    bytes32 internal integrityHash = keccak256("AOXC_XLAYER_MIGRATION_AUDIT");

    function setUp() public {
        AOXC v1Impl = new AOXC();
        bytes memory v1Init = abi.encodeWithSelector(AOXC.initialize.selector, governor);
        v1 = AOXC(address(new ERC1967Proxy(address(v1Impl), v1Init)));

        vm.prank(governor);
        v1.mint(user, 1_000 ether);

        vm.prank(governor);
        v1.setTransferVelocity(50 ether, 200 ether);
    }

    function test_MigrateInPlace_PreservesSupplyBalancesAndGovernanceParity() public {
        uint256 preSupply = v1.totalSupply();
        uint256 preUserBalance = v1.balanceOf(user);
        uint256 preYearlyMintLimit = v1.yearlyMintLimit();
        uint256 preMintedThisYear = v1.mintedThisYear();
        uint256 preLastMintTimestamp = v1.lastMintTimestamp();
        uint256 preMaxTransferAmount = v1.maxTransferAmount();
        uint256 preDailyTransferLimit = v1.dailyTransferLimit();

        AoxcCore v2Impl = new AoxcCore();

        vm.prank(governor);
        v1.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(
                AoxcCore.migrateFromV1.selector,
                address(v1),
                nexus,
                sentinel,
                address(0),
                governor,
                integrityHash
            )
        );

        AoxcCore v2 = AoxcCore(address(v1));

        assertEq(v2.totalSupply(), preSupply, "supply changed during migration");
        assertEq(v2.balanceOf(user), preUserBalance, "user balance changed during migration");

        (uint256 yearlyLimit, uint256 mintedThisYear, uint256 lastMintWindowStart) = v2.getMintPolicy();
        assertEq(yearlyLimit, preYearlyMintLimit, "yearly mint limit changed during migration");
        assertEq(mintedThisYear, preMintedThisYear, "mintedThisYear changed during migration");
        assertEq(lastMintWindowStart, preLastMintTimestamp, "lastMintTimestamp changed during migration");

        assertEq(v2.maxTransferAmount(), preMaxTransferAmount, "maxTransferAmount changed during migration");
        assertEq(v2.dailyTransferLimit(), preDailyTransferLimit, "dailyTransferLimit changed during migration");

        assertTrue(v2.hasRole(0x00, governor), "missing default admin");
        assertTrue(v2.hasRole(AoxcConstants.GOVERNANCE_ROLE, nexus), "missing governance role");
        assertTrue(v2.hasRole(AoxcConstants.SENTINEL_ROLE, sentinel), "missing sentinel role");
        assertTrue(v2.hasRole(AoxcConstants.UPGRADER_ROLE, governor), "missing upgrader role");
    }

    function test_MigrateInPlace_TransferVelocityAndBlacklistStillEnforced() public {
        address recipient = makeAddr("recipient");

        AoxcCore v2Impl = new AoxcCore();

        vm.prank(governor);
        v1.upgradeToAndCall(
            address(v2Impl),
            abi.encodeWithSelector(
                AoxcCore.migrateFromV1.selector,
                address(v1),
                nexus,
                sentinel,
                address(0),
                governor,
                integrityHash
            )
        );

        AoxcCore v2 = AoxcCore(address(v1));

        vm.prank(sentinel);
        v2.setRestrictionStatus(recipient, true, "NO_RECEIVE");

        vm.expectRevert();
        vm.prank(user);
        v2.transfer(recipient, 1 ether);

        vm.prank(sentinel);
        v2.setRestrictionStatus(recipient, false, "CLEARED");

        vm.expectRevert();
        vm.prank(user);
        v2.transfer(recipient, 60 ether);
    }
}
