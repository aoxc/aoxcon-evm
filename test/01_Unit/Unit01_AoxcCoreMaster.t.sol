// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AoxcCore} from "aoxc/core/AoxcCore.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AOXCoreMasterTest is Test {
    AoxcCore public core; // IAoxcCore yerine direkt tipini kullanalım (DOMAIN_SEPARATOR için)

    uint256 internal aiNodeKey = 0xADE1;
    address internal aiNode;
    uint256 internal userKey = 0xABC1;
    address internal user;

    address internal nexus = address(0x111);
    address internal admin = address(0x444);
    address internal mockSentinel = address(0xDEAF);
    address internal mockRepair = address(0xBEEF);

    function setUp() public {
        aiNode = vm.addr(aiNodeKey);
        user = vm.addr(userKey);

        // 1. Implementation Deployment
        AoxcCore coreImpl = new AoxcCore();

        // 2. Proxy Initialization
        // İlk kurulum initializeAkdeniz ile yapılır (V1/V2 Hybrid)
        bytes memory initData =
            abi.encodeCall(AoxcCore.initializeAkdeniz, (nexus, mockSentinel, mockRepair, admin, 1_000_000 * 1e18));

        ERC1967Proxy proxy = new ERC1967Proxy(address(coreImpl), initData);
        core = AoxcCore(payable(address(proxy)));

        // V2 özelliklerini aktif et (Az önce eklediğimiz parametresiz init)
        core.initializeV2();

        vm.label(aiNode, "AOXCAN_AI_NODE");
        vm.label(user, "Sovereign_User");
        vm.label(address(proxy), "AoxcCore_PROXY");

        // 4. Genesis Minting
        vm.prank(nexus);
        core.mint(user, 100_000 * 1e18);

        vm.roll(100);
    }

    function test_Asset_Mint_And_Restriction() public {
        uint256 amount = 1000 * 1e18;

        vm.prank(nexus);
        core.mint(user, amount);

        // FIX: 3 parametre (address, bool, reason)
        vm.prank(mockSentinel);
        core.setRestrictionStatus(user, true, "MALICIOUS_ACTIVITY_DETECTED");
        assertTrue(core.isRestricted(user), "Restriction failed to apply");
    }

    function test_Governance_Snapshot_Logic() public {
        uint256 balance = core.balanceOf(user);

        vm.prank(user);
        core.delegate(user);

        uint256 snapBlock = block.number;
        vm.roll(block.number + 5);

        assertEq(core.getPastVotes(user, snapBlock), balance, "Governance snapshot mismatch");
    }

    function testFuzz_Neural_Lock_And_Recovery(uint256 riskScore, uint256 recoverAmount) public {
        uint256 totalAsset = core.balanceOf(user);
        riskScore = bound(riskScore, 85, 100);
        recoverAmount = bound(recoverAmount, 1, totalAsset);

        uint256 nonce = core.nonces(aiNode);

        // EIP-712 StructHash
        bytes32 structHash =
            keccak256(abi.encode(keccak256("NeuralSignal(uint256 riskScore,uint256 nonce)"), riskScore, nonce));

        // FIX: DOMAIN_SEPARATOR artık AoxcCore tipi üzerinden erişilebilir
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiNodeKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Neural Guard Lock
        vm.prank(aiNode);
        core.processNeuralSignal(riskScore, nonce, signature);

        // LockCore'u admin olarak çağıralım (veya sentinel tetiklesin)
        vm.prank(admin);
        core.lockCore();

        assertTrue(core.isCoreLocked(), "Neural Guard failed to lock Core");

        // Recovery
        address safeVault = address(0x54FE);
        vm.prank(mockSentinel); // executeRecovery sentinel rolü ister
        core.executeRecovery(user, safeVault, recoverAmount, "AI_PROOF_001");

        assertEq(core.balanceOf(safeVault), recoverAmount, "Autonomous recovery failed");
    }
}
