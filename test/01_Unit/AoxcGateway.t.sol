// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AoxcGateway} from "aoxc-v2/access/AoxcGateway.sol";
import {MockToken} from "../mocks/MockToken.sol"; // Basit bir ERC20 mock lazım
import {MockSentinel} from "../mocks/MockSentinel.sol"; // Sentinel dogrulamasi icin

contract AoxcGatewayTest is Test {
    AoxcGateway public gateway;
    MockToken public token;
    MockSentinel public sentinel;

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address treasury = makeAddr("treasury");
    uint16 xLayerId = 196;

    function setUp() public {
        token = new MockToken("AoxcCore", "AOXC");
        sentinel = new MockSentinel();
        
        AoxcGateway impl = new AoxcGateway();
        bytes memory initData = abi.encodeWithSelector(
            AoxcGateway.initializeGatewayV3.selector,
            admin, address(token), address(sentinel), treasury
        );
        gateway = AoxcGateway(address(new ERC1967Proxy(address(impl), initData)));

        // XLayer destegini ac
        vm.prank(admin);
        gateway.updateChainSupport(xLayerId, true);

        // Kullaniciya token ver ve approve al
        token.mint(user, 1000 * 1e18);
        vm.prank(user);
        token.approve(address(gateway), type(uint256).max);
    }

    function test_InitiateMigration_Success() public {
        uint256 amount = 500 * 1e18;
        IAoxcCore.NeuralPacket memory packet;
        packet.riskScore = 50; // Güvenli skor

        // Sentinel'e bu paketi onayla dedirtiyoruz (Mock mantigi)
        sentinel.setValidationResult(true);

        uint256 initialTreasuryBalance = token.balanceOf(treasury);
        
        vm.prank(user);
        gateway.initiateMigration(xLayerId, user, amount, packet);

        // Komisyon kontrolü (30 BPS = %0.3)
        uint256 expectedFee = (amount * 30) / 10000;
        assertEq(token.balanceOf(treasury) - initialTreasuryBalance, expectedFee, "Fee failed");
        assertEq(token.balanceOf(address(gateway)), amount - expectedFee, "Net amount failed");
        
        console.log(">> Gateway Migration Initiated & AI Cleared.");
    }
}
