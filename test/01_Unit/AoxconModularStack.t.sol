// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AoxconHonor} from "../../src/aoxcon/solidity/AoxconHonor.sol";
import {AoxconXasToken} from "../../src/aoxcon/solidity/AoxconXasToken.sol";
import {AoxconBridge} from "../../src/aoxcon/solidity/AoxconBridge.sol";
import {AoxconVerifierRegistry} from "../../src/aoxcon/solidity/AoxconVerifierRegistry.sol";

contract MockVerifier {
    bool public result = true;
    function setResult(bool value) external { result = value; }
    function verify(bytes calldata, bytes calldata) external view returns (bool) { return result; }
}

contract AoxconModularStackTest is Test {
    using SafeERC20 for IERC20;
    address admin = makeAddr("admin");
    uint256 signerPk = 0xA11CE;
    address signer;
    address user = makeAddr("user");

    AoxconHonor honor;
    AoxconXasToken xas;
    AoxconVerifierRegistry registry;
    AoxconBridge bridge;
    MockVerifier verifier;

    function setUp() public {
        signer = vm.addr(signerPk);

        bytes32 root = keccak256(bytes.concat(keccak256(abi.encode(user, 100 ether, 10_000))));
        honor = new AoxconHonor(admin, root);

        xas = new AoxconXasToken(admin);
        registry = new AoxconVerifierRegistry(admin);
        bridge = new AoxconBridge(admin, address(xas), address(registry), signer);
        verifier = new MockVerifier();

        vm.prank(admin);
        xas.setBridge(address(bridge));

        vm.prank(admin);
        registry.setVerifier(block.chainid, address(verifier));
    }

    function test_Honor_Claim_And_NonTransferable() public {
        bytes32[] memory proof = new bytes32[](0);
        vm.prank(user);
        honor.claim(100 ether, 10_000, proof);

        assertEq(honor.balanceOf(user), 100 ether);

        vm.expectRevert("HONOR: NON_TRANSFERABLE");
        vm.prank(user);
        IERC20(address(honor)).safeTransfer(admin, 1);
    }

    function test_Bridge_InboundMint_DualVerification() public {
        AoxconBridge.BridgeTicket memory t = AoxconBridge.BridgeTicket({
            user: user,
            amount: 50 ether,
            sourceChainId: block.chainid,
            nonce: 0,
            deadline: block.timestamp + 1 hours,
            refId: keccak256("op-1")
        });

        bytes32 digest = keccak256(
            abi.encode(
                bridge.domainSeparator(),
                t.user,
                t.amount,
                t.sourceChainId,
                t.nonce,
                t.deadline,
                t.refId
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)));
        bytes memory sig = abi.encodePacked(r, s, v);

        bridge.inboundMint(t, sig, hex"1234");
        assertEq(xas.balanceOf(user), 50 ether);
    }
}
