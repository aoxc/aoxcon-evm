// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "aoxc-v2/core/AoxcCore.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";
import "aoxc-v2/libraries/AoxcErrors.sol";

contract AoxcCoreTest is Test {
    AoxcCore public core;
    
    address admin = makeAddr("admin");
    address nexus = makeAddr("nexus");
    address sentinel = makeAddr("sentinel");
    address user = makeAddr("user");
    bytes32 integrityHash = keccak256("AOXC_V2_GENESIS");

    function setUp() public {
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


    function test_Revert_InitializeV2_ZeroAdmin() public {
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
}
