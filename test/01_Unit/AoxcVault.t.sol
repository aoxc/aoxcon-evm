// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "aoxc-v2/finance/AoxcVault.sol";
import "../mocks/MockCore.sol";
import "../mocks/MockToken.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";
import "aoxc-v2/libraries/AoxcErrors.sol";

/**
 * @title AoxcVaultTest
 * @notice Unit tests for AOXC Sovereign Treasury with Neural Handshake.
 */
contract AoxcVaultTest is Test {
    AoxcVault public vault;
    MockCore public core;
    MockToken public token;

    address admin = makeAddr("admin");
    address user = makeAddr("user");

    function setUp() public {
        core = new MockCore();
        token = new MockToken("AoxcCore", "AOXC");
        
        AoxcVault impl = new AoxcVault();
        bytes memory initData = abi.encodeWithSelector(
            AoxcVault.initializeVaultV2.selector,
            address(core), address(token), admin
        );
        
        // FIX: Explicit type conversion for payable contracts (Solidity 0.8.0+)
        vault = AoxcVault(payable(address(new ERC1967Proxy(address(impl), initData))));

        // Kasaya başlangıç likiditesini yükle
        token.mint(address(vault), 1000 * 1e18);
        vm.deal(address(vault), 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawErc20_Success() public {
        uint256 amount = 100 * 1e18;
        IAoxcCore.NeuralPacket memory packet;
        packet.value = amount;
        packet.riskScore = 50;

        vm.prank(admin);
        vault.withdrawErc20(address(token), user, amount, packet);

        assertEq(token.balanceOf(user), amount);
        console.log(">> ERC20 Withdrawal Success: 100 AOXC");
    }

    function test_WithdrawEth_Success() public {
        uint256 amount = 1 ether;
        IAoxcCore.NeuralPacket memory packet;
        packet.value = amount;

        vm.prank(admin);
        vault.withdrawEth(payable(user), amount, packet);

        assertEq(user.balance, amount);
        console.log(">> ETH Withdrawal Success: 1 ETH");
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY & REPAIR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_WithdrawWhenSealed() public {
        IAoxcCore.NeuralPacket memory packet;
        packet.riskScore = 50;

        // 1. Sistemi Sentinel rolüyle mühürleyelim
        vm.startPrank(admin);
        vault.grantRole(AoxcConstants.SENTINEL_ROLE, admin);
        vault.proposeSelfHealing(address(0x123), packet);
        vm.stopPrank();

        assertTrue(vault.isVaultLocked());

        // 2. Mühürlüyken para çekmeye çalışalım (REVERT BEKLENİYOR)
        vm.expectRevert(AoxcErrors.Aoxc_GlobalLockActive.selector);
        vm.prank(admin);
        vault.withdrawEth(payable(user), 1 ether, packet);
        
        console.log(">> Security: Vault correctly blocked withdrawal while Sealed.");
    }

    function test_Full_SelfHealing_Cycle() public {
        IAoxcCore.NeuralPacket memory packet;
        packet.riskScore = 20;
        packet.protocolHash = keccak256("REPAIR_V1");
        
        // --- KRITIK DÜZELTME ---
        // Sistem kilitliyken (Sealed) modifier'dan geçmek için bu kod şarttır.
        packet.reasonCode = AoxcConstants.REASON_REPAIR_OVERRIDE;

        address newLogic = address(new AoxcVault()); 

        vm.startPrank(admin);
        // Yetkileri tanımlayalım
        vault.grantRole(AoxcConstants.SENTINEL_ROLE, admin);
        vault.grantRole(AoxcConstants.GOVERNANCE_ROLE, admin);

        // 1. Propose (Sistem mühürlenir)
        vault.proposeSelfHealing(newLogic, packet);
        assertTrue(vault.isVaultLocked());
        
        // 2. Cooldown simülasyonu
        skip(AoxcConstants.REPAIR_TIMELOCK + 1);

        // 3. Finalize (Override kodu sayesinde modifier'ı geçer)
        vault.finalizeSelfHealing(packet);
        vm.stopPrank();

        assertFalse(vault.isVaultLocked());
        console.log(">> Self-Healing Cycle Completed and Vault Unsealed.");
    }

    /*//////////////////////////////////////////////////////////////
                            ANALYTICS VIEWS
    //////////////////////////////////////////////////////////////*/

    function test_Vault_State_Views() public view {
        assertEq(vault.getVaultTvl(), 10 ether);
        assertEq(vault.getRemainingLimit(user), 1_000_000 * 1e18);
    }
}
