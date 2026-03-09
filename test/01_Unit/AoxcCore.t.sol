// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "aoxc-v2/core/AoxcCore.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";
import "aoxc-v2/libraries/AoxcErrors.sol";

contract MockSentinelLocal {
    function validateNeuralPacket(IAoxcCore.NeuralPacket calldata) external pure returns (bool) {
        return true;
    }
}

contract AoxcCoreTest is Test {
    AoxcCore public core;
    
    address admin = makeAddr("admin");
    address nexus = makeAddr("nexus");
    address sentinel;
    MockSentinelLocal sentinelMock;
    address user = makeAddr("user");
    bytes32 integrityHash = keccak256("AOXC_V2_GENESIS");

    function setUp() public {
        sentinelMock = new MockSentinelLocal();
        sentinel = address(sentinelMock);

        AoxcCore impl = new AoxcCore();
        bytes memory initData = abi.encodeWithSelector(
            AoxcCore.initializeV2.selector,
            address(0), // No V1 for now
            nexus,
            sentinel,
            address(0), // No repair for now
            admin,
            integrityHash
        );
        core = AoxcCore(address(new ERC1967Proxy(address(impl), initData)));
    }

    /*//////////////////////////////////////////////////////////////
                            TOKEN LOGIC
    //////////////////////////////////////////////////////////////*/

    function test_Mint_By_Governance() public {
        uint256 amount = 1000 * 1e18;
        
        vm.prank(nexus); // Sadece Governance mint edebilir
        core.mint(user, amount);
        
        assertEq(core.balanceOf(user), amount);
        assertEq(core.totalSupply(), amount);
    }

    function test_Revert_Mint_By_NonGov() public {
        vm.expectRevert();
        vm.prank(user);
        core.mint(user, 100);
    }


    function test_Mint_Revert_YearlyInflationLimit() public {
        uint256 yearlyLimit = 6_000_000_000 * 1e18;
        vm.startPrank(nexus);
        core.mint(user, yearlyLimit);
        vm.expectRevert();
        core.mint(user, 1);
        vm.stopPrank();
    }

    function test_Mint_ResetsAfterYearWindow() public {
        uint256 yearlyLimit = 6_000_000_000 * 1e18;
        vm.prank(nexus);
        core.mint(user, yearlyLimit);

        vm.warp(block.timestamp + 366 days);

        vm.prank(nexus);
        core.mint(user, 1);

        assertEq(core.balanceOf(user), yearlyLimit + 1);
    }


    function test_Revert_InitializeV2_ZeroAdmin() public {
        sentinelMock = new MockSentinelLocal();
        sentinel = address(sentinelMock);

        AoxcCore impl = new AoxcCore();
        bytes memory initData = abi.encodeWithSelector(
            AoxcCore.initializeV2.selector,
            address(0),
            nexus,
            sentinel,
            address(0),
            address(0),
            integrityHash
        );

        vm.expectRevert(AoxcErrors.Aoxc_InvalidAddress.selector);
        new ERC1967Proxy(address(impl), initData);
    }

    function test_Revert_InitializeV2_ZeroIntegrityHash() public {
        sentinelMock = new MockSentinelLocal();
        sentinel = address(sentinelMock);

        AoxcCore impl = new AoxcCore();
        bytes memory initData = abi.encodeWithSelector(
            AoxcCore.initializeV2.selector,
            address(0),
            nexus,
            sentinel,
            address(0),
            admin,
            bytes32(0)
        );

        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_CustomRevert.selector, "CORE: ZERO_INTEGRITY_HASH"));
        new ERC1967Proxy(address(impl), initData);
    }

    /*//////////////////////////////////////////////////////////////
                            NEURAL GATING
    //////////////////////////////////////////////////////////////*/

    function test_ExecuteNeuralAction_Success() public {
        IAoxcCore.NeuralPacket memory packet;
        packet.origin = user;
        packet.nonce = 0;
        packet.deadline = uint48(block.timestamp + 100);
        packet.protocolHash = integrityHash;

        bool result = core.executeNeuralAction(packet);
        assertTrue(result, "Neural action should be approved");
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY ACTIONS
    //////////////////////////////////////////////////////////////*/

    function test_Blacklist_Gating() public {
        // User'a para verelim
        vm.prank(nexus);
        core.mint(user, 500);

        // Sentinel kullanıcıyı kara listeye alsın
        vm.prank(sentinel);
        core.setRestrictionStatus(user, true, "SUSPICIOUS_ACTIVITY");

        // Kara listedeki kullanıcı transfer yapamasın
        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 100);
    }


    function test_TransferVelocity_MaxTx_Enforced() public {
        vm.prank(nexus);
        core.mint(user, 2_000);

        vm.prank(admin);
        core.setTransferVelocity(100, 10_000);

        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 101);
    }

    function test_TransferVelocity_DailyLimit_Enforced() public {
        vm.prank(nexus);
        core.mint(user, 500);

        vm.prank(admin);
        core.setTransferVelocity(1_000, 200);

        vm.prank(user);
        core.transfer(admin, 150);

        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 60);
    }

    function test_Blacklisted_Recipient_CannotReceive() public {
        vm.prank(nexus);
        core.mint(user, 200);

        vm.prank(sentinel);
        core.setRestrictionStatus(admin, true, "NO_RECEIVE");

        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 10);
    }

    function test_Pause_Unpause_By_Sentinel() public {
        vm.prank(sentinel);
        core.pause();

        vm.prank(nexus);
        core.mint(user, 100);

        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 1);

        vm.prank(sentinel);
        core.unpause();

        vm.prank(user);
        core.transfer(admin, 1);
    }



    function test_CriticalAddress_RequiresNeuralPermit() public {
        vm.prank(admin);
        core.setCriticalAddress(user, true);

        vm.prank(nexus);
        core.mint(user, 100);

        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 1);
    }

    function test_CriticalAddress_WithPreparedPermit_AllowsTransfer() public {
        vm.prank(admin);
        core.setCriticalAddress(user, true);

        vm.prank(nexus);
        core.mint(user, 100);

        IAoxcCore.NeuralPacket memory p;
        p.origin = user;
        p.target = admin;
        p.value = 1;
        p.deadline = uint48(block.timestamp + 1 days);
        p.riskScore = 1;
        p.protocolHash = integrityHash;

        vm.prank(user);
        core.prepareNeuralTransfer(admin, 1, p);

        vm.prank(user);
        core.transfer(admin, 1);
    }



    function test_OptInMode_RequiresPermit() public {
        vm.prank(user);
        core.setNeuralProtectMode(true);

        vm.prank(nexus);
        core.mint(user, 10);

        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 1);
    }

    function test_Permit_Expires() public {
        vm.prank(admin);
        core.setCriticalAddress(user, true);

        vm.prank(nexus);
        core.mint(user, 100);

        IAoxcCore.NeuralPacket memory p;
        p.origin = user;
        p.target = admin;
        p.value = 1;
        p.deadline = uint48(block.timestamp + 1);
        p.riskScore = 1;
        p.protocolHash = integrityHash;

        vm.prank(user);
        core.prepareNeuralTransfer(admin, 1, p);

        vm.warp(block.timestamp + 2);
        vm.expectRevert();
        vm.prank(user);
        core.transfer(admin, 1);
    }

}
