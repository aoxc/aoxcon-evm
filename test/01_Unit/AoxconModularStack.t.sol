// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AoxconHonor} from "../../src/aoxcon/solidity/AoxconHonor.sol";
import {AoxconXasToken} from "../../src/aoxcon/solidity/AoxconXasToken.sol";
import {AoxconBridge} from "../../src/aoxcon/solidity/AoxconBridge.sol";
import {AoxconVerifierRegistry} from "../../src/aoxcon/solidity/AoxconVerifierRegistry.sol";
import {AoxconCore} from "../../src/aoxcon/solidity/AoxconCore.sol";

contract MockVerifier {
    bool public result = true;

    function setResult(bool value) external {
        result = value;
    }

    function verify(bytes calldata, bytes calldata) external view returns (bool) {
        return result;
    }
}

contract AoxconModularStackTest is Test {
    address admin = makeAddr("admin");
    address user = makeAddr("user");
    uint256 signerPk = 0xA11CE;
    address signer;

    AoxconHonor honor;
    AoxconXasToken xas;
    AoxconVerifierRegistry registry;
    AoxconBridge bridge;
    AoxconCore core;
    MockVerifier verifier;

    function setUp() public {
        signer = vm.addr(signerPk);
        verifier = new MockVerifier();

        bytes32 root = keccak256(bytes.concat(keccak256(abi.encode(user, 100 ether, 10_000))));

        honor = AoxconHonor(_deployProxy(address(new AoxconHonor()), abi.encodeWithSelector(
            AoxconHonor.initialize.selector, admin, root, block.timestamp - 1, block.timestamp + 7 days
        )));

        xas = AoxconXasToken(_deployProxy(address(new AoxconXasToken()), abi.encodeWithSelector(
            AoxconXasToken.initialize.selector, admin
        )));

        registry = AoxconVerifierRegistry(_deployProxy(address(new AoxconVerifierRegistry()), abi.encodeWithSelector(
            AoxconVerifierRegistry.initialize.selector, admin
        )));

        bridge = AoxconBridge(_deployProxy(address(new AoxconBridge()), abi.encodeWithSelector(
            AoxconBridge.initialize.selector, admin, address(xas), address(registry), signer
        )));

        core = AoxconCore(_deployProxy(address(new AoxconCore()), abi.encodeWithSelector(
            AoxconCore.initialize.selector, admin, keccak256("INITIAL_CONFIG")
        )));

        vm.startPrank(admin);
        core.bindModules(address(honor), address(xas), address(bridge), address(registry));
        core.wireBridgeToXas();
        core.configureVerifier(block.chainid, address(verifier), true, "xlayer-verifier");
        vm.stopPrank();
    }

    function test_HonorClaimAndNonTransferable() public {
        vm.prank(user);
        honor.claim(100 ether, 10_000, new bytes32[](0));

        assertEq(honor.balanceOf(user), 100 ether);

        vm.expectRevert("HONOR: NON_TRANSFERABLE");
        vm.prank(user);
        honor.transfer(admin, 1);
    }

    function test_BridgeInboundMint_Success() public {
        AoxconBridge.BridgeTicket memory ticket = _ticket(AoxconBridge.Direction.Inbound, 0, block.chainid, 50 ether);

        bytes memory sig = _sign(ticket);

        bridge.inboundMint(ticket, sig, hex"0102");

        assertEq(xas.balanceOf(user), 50 ether);
        assertEq(bridge.nonces(user), 1);
    }

    function test_BridgeInboundMint_ReplayBlocked() public {
        AoxconBridge.BridgeTicket memory ticket = _ticket(AoxconBridge.Direction.Inbound, 0, block.chainid, 25 ether);
        bytes memory sig = _sign(ticket);

        bridge.inboundMint(ticket, sig, hex"aa");

        vm.expectRevert("BRIDGE: BAD_NONCE");
        bridge.inboundMint(ticket, sig, hex"aa");
    }

    function test_BridgeInboundMint_BadZkRejected() public {
        AoxconBridge.BridgeTicket memory ticket = _ticket(AoxconBridge.Direction.Inbound, 0, block.chainid, 25 ether);
        bytes memory sig = _sign(ticket);

        verifier.setResult(false);

        vm.expectRevert("BRIDGE: BAD_ZK");
        bridge.inboundMint(ticket, sig, hex"aa");
    }

    function test_XasBridgeRotation_RevokesOldBridge() public {
        address fakeBridge = makeAddr("fakeBridge");

        vm.prank(admin);
        xas.rotateBridge(fakeBridge);

        vm.expectRevert();
        bridge.inboundMint(_ticket(AoxconBridge.Direction.Inbound, 0, block.chainid, 10 ether), _sign(_ticket(AoxconBridge.Direction.Inbound, 0, block.chainid, 10 ether)), hex"11");
    }

    function _deployProxy(address implementation, bytes memory initData) internal returns (address) {
        return address(new ERC1967Proxy(implementation, initData));
    }

    function _ticket(AoxconBridge.Direction direction, uint256 nonce, uint256 remoteChain, uint256 amount)
        internal
        view
        returns (AoxconBridge.BridgeTicket memory)
    {
        if (direction == AoxconBridge.Direction.Inbound) {
            return AoxconBridge.BridgeTicket({
                user: user,
                amount: amount,
                sourceChainId: remoteChain,
                targetChainId: block.chainid,
                nonce: nonce,
                deadline: block.timestamp + 1 hours,
                refId: keccak256(abi.encode("inbound", nonce, amount)),
                direction: direction
            });
        }

        return AoxconBridge.BridgeTicket({
            user: user,
            amount: amount,
            sourceChainId: block.chainid,
            targetChainId: remoteChain,
            nonce: nonce,
            deadline: block.timestamp + 1 hours,
            refId: keccak256(abi.encode("outbound", nonce, amount)),
            direction: direction
        });
    }

    function _sign(AoxconBridge.BridgeTicket memory ticket) internal view returns (bytes memory) {
        bytes32 structHash = keccak256(
            abi.encode(
                bridge.TICKET_TYPEHASH(),
                ticket.user,
                ticket.amount,
                ticket.sourceChainId,
                ticket.targetChainId,
                ticket.nonce,
                ticket.deadline,
                ticket.refId,
                ticket.direction
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", bridge.eip712DomainSeparator(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return abi.encodePacked(r, s, v);
    }
}
