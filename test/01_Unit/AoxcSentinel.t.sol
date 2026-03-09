// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "aoxc-v2/access/AoxcSentinel.sol";
import "aoxc-v2/libraries/AoxcConstants.sol";
import "aoxc-v2/libraries/AoxcErrors.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";

/**
 * @title AoxcSentinelAuditTest
 * @notice Full audit suite for Sentinel EIP-712 Neural Handshake.
 * @dev Replaces internal visibility issues with Proxy-based testing.
 */
contract AoxcSentinelAuditTest is Test {
    AoxcSentinel public sentinel;
    
    // AI Node Private Key (Simulation for EIP-712)
    uint256 internal aiPrivateKey = 0xA1B2C3;
    address internal aiNodeAddress;

    address admin = makeAddr("admin");
    address core = makeAddr("core");
    address attacker = makeAddr("attacker");

    // EIP-712 TypeHash matching the contract logic
    bytes32 private constant NEURAL_PACKET_TYPEHASH =
        keccak256("NeuralPacket(address origin,address target,uint256 value,uint256 nonce,uint48 deadline,uint16 reasonCode,uint8 riskScore,bool autoRepairMode,bytes32 protocolHash)");

    function setUp() public {
        aiNodeAddress = vm.addr(aiPrivateKey);
        
        // 1. Deploy Implementation
        AoxcSentinel implementation = new AoxcSentinel();
        
        // 2. Prepare Proxy Initialization Data
        bytes memory initData = abi.encodeWithSelector(
            AoxcSentinel.initializeV2.selector,
            admin,
            aiNodeAddress,
            core,
            address(0) // No repair engine for unit test
        );
        
        // 3. Deploy Proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        sentinel = AoxcSentinel(address(proxy));
    }

    /*//////////////////////////////////////////////////////////////
                            SUCCESS SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_Audit_ValidHandshake() public {
        IAoxcCore.NeuralPacket memory packet = _createBasePacket();
        packet.neuralSignature = _signPacket(packet);

        bool isValid = sentinel.verifyHandshake(packet);
        assertTrue(isValid, "Valid AI handshake should pass");
    }

    /*//////////////////////////////////////////////////////////////
                            SECURITY SCENARIOS
    //////////////////////////////////////////////////////////////*/

    function test_Revert_IdentityForgery() public {
        IAoxcCore.NeuralPacket memory packet = _createBasePacket();
        
        // Sign with a malicious/wrong key
        uint256 fakeKey = 0xBAD;
        bytes32 structHash = keccak256(abi.encode(
            NEURAL_PACKET_TYPEHASH, 
            packet.origin, packet.target, packet.value, packet.nonce, 
            packet.deadline, packet.reasonCode, packet.riskScore, 
            packet.autoRepairMode, packet.protocolHash
        ));
        
        // Use the Domain Separator from the proxy contract
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", sentinel.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fakeKey, digest);
        packet.neuralSignature = abi.encodePacked(r, s, v);

        bool isValid = sentinel.verifyHandshake(packet);
        assertFalse(isValid, "Sentinel must reject forged signatures");
    }

    function test_Revert_ExpiredPacket() public {
        IAoxcCore.NeuralPacket memory packet = _createBasePacket();
        packet.deadline = uint48(block.timestamp - 1); // Expired
        packet.neuralSignature = _signPacket(packet);

        bool isValid = sentinel.verifyHandshake(packet);
        assertFalse(isValid, "Sentinel must reject expired packets");
    }

    function test_Revert_HighRiskExceeded() public {
        IAoxcCore.NeuralPacket memory packet = _createBasePacket();
        // Assuming riskThreshold is default (usually < 255)
        packet.riskScore = 255; 
        packet.neuralSignature = _signPacket(packet);

        bool isValid = sentinel.verifyHandshake(packet);
        assertFalse(isValid, "Sentinel must block risk scores above threshold");
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Helper to sign packet using the simulated AI private key.
     */
    function _signPacket(IAoxcCore.NeuralPacket memory p) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(abi.encode(
            NEURAL_PACKET_TYPEHASH,
            p.origin, p.target, p.value, p.nonce, p.deadline, p.reasonCode, p.riskScore, p.autoRepairMode, p.protocolHash
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", sentinel.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiPrivateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev Helper to generate a standardized neural packet.
     */
    function _createBasePacket() internal view returns (IAoxcCore.NeuralPacket memory) {
        return IAoxcCore.NeuralPacket({
            origin: attacker,
            target: core,
            value: 0,
            nonce: 1,
            deadline: uint48(block.timestamp + 100),
            reasonCode: 1,
            riskScore: 50, // Safe level (below AoxcConstants.NEURAL_RISK_CRITICAL)
            autoRepairMode: false,
            protocolHash: keccak256("GENESIS_V2"),
            neuralSignature: ""
        });
    }
}
