// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AoxcRegistry} from "aoxc-v2/core/AoxcRegistry.sol";
import {AoxcSentinel} from "aoxc-v2/access/AoxcSentinel.sol";
import {AoxcAutoRepair} from "aoxc-v2/infra/AoxcAutoRepair.sol";
import {AoxcConstants} from "aoxc-v2/libraries/AoxcConstants.sol";
import {MockCore} from "../mocks/MockCore.sol";

/**
 * @title Operation Red Cell: Full Neural Defense & Auto-Repair Integration
 * @notice Validates the synergy between Detection, Isolation, and Quarantine.
 */
contract AoxcWarRoom is Test {
    AoxcRegistry public registry;
    AoxcSentinel public sentinel;
    AoxcAutoRepair public autoRepair;
    MockCore public core;

    uint256 internal aiKey = 0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123ab01;
    address internal aiNode;
    address admin = makeAddr("AOXC_High_Command");
    address nexus = makeAddr("NEXUS_GOVERNANCE");
    address attacker = makeAddr("Malicious_Bot");

    function setUp() public {
        aiNode = vm.addr(aiKey);
        
        // 1. Core Mock Deployment
        core = new MockCore();

        // 2. Registry Deployment
        AoxcRegistry regImpl = new AoxcRegistry();
        registry = AoxcRegistry(address(new ERC1967Proxy(address(regImpl), 
            abi.encodeWithSelector(AoxcRegistry.initializeRegistryV2.selector, admin))));

        // 3. AutoRepair Deployment
        AoxcAutoRepair repairImpl = new AoxcAutoRepair();
        autoRepair = AoxcAutoRepair(address(new ERC1967Proxy(address(repairImpl), 
            abi.encodeWithSelector(AoxcAutoRepair.initializeAutoRepairV2.selector, 
            admin, address(core), nexus, aiNode, admin))));

        // 4. Sentinel Deployment (AutoRepair engine adresi eklenmiştir)
        AoxcSentinel sentImpl = new AoxcSentinel();
        sentinel = AoxcSentinel(address(new ERC1967Proxy(address(sentImpl), 
            abi.encodeWithSelector(AoxcSentinel.initializeV2.selector, 
            admin, aiNode, address(core), address(autoRepair)))));

        // 5. Onboard Attacker to Registry
        vm.prank(admin);
        registry.onboardMember(attacker);
    }

    function test_Operation_RedCell_EndToEnd_Defense() public {
        // --- PHASE 1: DETECTION (AI Logic) ---
        uint8 criticalRisk = AoxcConstants.NEURAL_RISK_CRITICAL + 10; 
        uint256 nonce = 1001;
        bytes4 targetSelector = bytes4(keccak256("drainVault()"));

        // EIP-712 Interception Signature
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Interception(uint8 riskScore,uint256 nonce,address target,bytes4 selector)"),
            criticalRisk, nonce, attacker, targetSelector
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", sentinel.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiKey, digest);
        bytes memory aiSignature = abi.encodePacked(r, s, v);

        // --- PHASE 2: INTERCEPTION & ISOLATION ---
        console.log(">> AOXCAN AI: High Risk Detected (Score: %s)", criticalRisk);
        
        // Sentinel yakalar -> Core'u arar -> AutoRepair'i tetikler
        sentinel.processInterception(criticalRisk, nonce, attacker, targetSelector, aiSignature);

        // --- PHASE 3: VERIFICATION (The Synergy) ---
        
        // A. Core Check: Attacker mühürlendi mi?
        assertTrue(core.isRestricted(attacker), "Core failed to isolate attacker");
        console.log(">> Status: Attacker Restricted in Core");

        // B. AutoRepair Check: Hedef fonksiyon karantinaya alindi mi?
        // AutoRepair::isOperational(targetSelector) -> false dönmeli (çünkü karantinada)
        vm.prank(attacker); // msg.sender target contract simülasyonu
        assertFalse(autoRepair.isOperational(targetSelector), "AutoRepair failed to quarantine selector");
        console.log(">> Status: Target Function Quarantined by AutoRepair");

        // C. Registry Check: İtibar sıfırlama
        vm.prank(admin);
        registry.adjustReputation(attacker, -500, AoxcConstants.REASON_DEFENSE_TRIGGER);

        IAoxcStorage.CitizenRecord memory record = registry.getCitizenRecord(attacker);
        assertTrue(record.isBlacklisted, "Registry failed to blacklist");
        console.log(">> Status: Attacker Blacklisted. Ecosystem Cleansed.");
    }
}
