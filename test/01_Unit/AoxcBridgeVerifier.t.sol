// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AoxcBridgeVerifier} from "aoxc-v2/bridge/AoxcBridgeVerifier.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";

contract AoxcBridgeVerifierTest is Test {
    AoxcBridgeVerifier internal verifier;

    uint256 internal adminPk = 0xA11CE;
    uint256 internal signerPk = 0xB0B;
    address internal admin;
    address internal signer;
    address internal origin;
    address internal target;

    bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 internal constant PACKET_TYPEHASH =
        keccak256(
            "UnifiedNeuralPacket(uint8 commandType,address origin,address target,uint256 value,uint256 nonce,uint48 deadline,uint16 reasonCode,uint8 riskScore,uint256 sourceChainId,bytes32 payloadHash)"
        );

    function setUp() public {
        admin = vm.addr(adminPk);
        signer = vm.addr(signerPk);
        origin = makeAddr("origin");
        target = makeAddr("target");

        AoxcBridgeVerifier impl = new AoxcBridgeVerifier();
        bytes memory initData = abi.encodeWithSelector(AoxcBridgeVerifier.initialize.selector, admin, signer);
        verifier = AoxcBridgeVerifier(address(new ERC1967Proxy(address(impl), initData)));

        vm.startPrank(admin);
        verifier.setSourceChainSupport(777, true);
        vm.stopPrank();
    }

    function test_VerifyAndConsume_Success() public {
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, signerPk, 777, 0);
        bytes32 packetId = verifier.verifyAndConsume(packet);

        assertTrue(verifier.consumedPackets(packetId));
        assertEq(verifier.nonces(origin), 1);
    }

    function test_VerifyAndConsume_RevertWhenPaused() public {
        vm.prank(admin);
        verifier.setPaused(true);

        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, signerPk, 777, 0);
        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_CustomRevert.selector, "BRIDGE: PAUSED"));
        verifier.verifyAndConsume(packet);
    }

    function test_VerifyAndConsume_RevertWhenWrongSigner() public {
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, adminPk, 777, 0);
        vm.expectRevert();
        verifier.verifyAndConsume(packet);
    }

    function test_VerifyAndConsume_RevertWhenSourceChainUnsupported() public {
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, signerPk, 999, 0);
        vm.expectRevert();
        verifier.verifyAndConsume(packet);
    }


    function test_VerifyAndConsume_RevertWhenEmptyPayloadHash() public {
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, signerPk, 777, 0);
        packet.payloadHash = bytes32(0);
        packet.signature = _signPacket(packet, signerPk);

        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_CustomRevert.selector, "BRIDGE: EMPTY_PAYLOAD_HASH"));
        verifier.verifyAndConsume(packet);
    }

    function test_VerifyAndConsume_RevertWhenBadSignatureLength() public {
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, signerPk, 777, 0);
        packet.signature = hex"1234";

        vm.expectRevert(abi.encodeWithSelector(AoxcErrors.Aoxc_CustomRevert.selector, "BRIDGE: BAD_SIG_LENGTH"));
        verifier.verifyAndConsume(packet);
    }

    function test_ComputePacketId_DiffersByCommandType() public {
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packetTransfer = _buildPacket(0, signerPk, 777, 0);
        AoxcBridgeVerifier.UnifiedNeuralPacket memory packetBlacklist = _buildPacket(0, signerPk, 777, 0);
        packetBlacklist.commandType = AoxcBridgeVerifier.CommandType.BLACKLIST;
        packetBlacklist.signature = _signPacket(packetBlacklist, signerPk);

        bytes32 transferId = verifier.computePacketId(packetTransfer);
        bytes32 blacklistId = verifier.computePacketId(packetBlacklist);

        assertTrue(transferId != blacklistId, "packet id must include command type");
    }

    function test_GovernanceCanRotateSigner() public {
        uint256 newSignerPk = 0xC0DE;
        address newSigner = vm.addr(newSignerPk);

        vm.prank(admin);
        verifier.setBridgeSigner(newSigner);

        AoxcBridgeVerifier.UnifiedNeuralPacket memory packet = _buildPacket(0, newSignerPk, 777, 0);
        verifier.verifyAndConsume(packet);
    }

    function _signPacket(AoxcBridgeVerifier.UnifiedNeuralPacket memory packet, uint256 signingKey)
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                PACKET_TYPEHASH,
                uint8(packet.commandType),
                packet.origin,
                packet.target,
                packet.value,
                packet.nonce,
                packet.deadline,
                packet.reasonCode,
                packet.riskScore,
                packet.sourceChainId,
                packet.payloadHash
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("AoxcBridgeVerifier")),
                keccak256(bytes("1")),
                block.chainid,
                address(verifier)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signingKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _buildPacket(
        uint256 nonce,
        uint256 signingKey,
        uint256 chainId,
        uint48 deadlineOffset
    ) internal view returns (AoxcBridgeVerifier.UnifiedNeuralPacket memory packet) {
        packet.commandType = AoxcBridgeVerifier.CommandType.TRANSFER;
        packet.origin = origin;
        packet.target = target;
        packet.value = 1 ether;
        packet.nonce = nonce;
        packet.deadline = uint48(block.timestamp + 30 minutes + deadlineOffset);
        packet.reasonCode = 100;
        packet.riskScore = 20;
        packet.sourceChainId = chainId;
        packet.payloadHash = keccak256("payload");

        packet.signature = _signPacket(packet, signingKey);
    }
}
