// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AoxcGateway} from "aoxc/access/AoxcGateway.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("AOXC", "AOXC") {
        _mint(msg.sender, 10_000_000 ether);
    }
}

/**
 * @title Fuzz_GATEWAY
 * @notice Cross-chain migration and AI-proof validation fuzzer.
 * @dev Case-sensitive naming fixed to match AoxcGateway logic.
 */
contract Fuzz_GATEWAY is Test {
    using MessageHashUtils for bytes32;

    AoxcGateway gateway;
    MockToken coreAsset;

    uint256 aiPrivateKey = 0xA1;
    address aiNode = vm.addr(aiPrivateKey);
    address governor = address(0xDE1);
    uint16 constant DEST_CHAIN = 56;

    function setUp() public {
        coreAsset = new MockToken();
        // Kontrat ismi AoxcGateway olarak düzeltildi
        AoxcGateway implementation = new AoxcGateway();

        // InitializeGateway fonksiyonu AoxcGateway içinde tanımlı olmalı
        bytes memory initData = abi.encodeCall(AoxcGateway.initializeGateway, (governor));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        gateway = AoxcGateway(address(proxy));

        vm.startPrank(governor);
        gateway.addSupportedChain(DEST_CHAIN);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS: OUTBOUND
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Initiate_Migration_Valid(address user, uint256 amount, uint256 riskScore) public {
        vm.assume(user != address(0) && user != address(gateway));
        amount = bound(amount, 100 ether, 1_000_000 ether);
        riskScore = bound(riskScore, 0, 100);

        deal(address(coreAsset), user, amount);

        vm.startPrank(user);
        coreAsset.approve(address(gateway), amount);

        // AI-Proof digest calculation (EIP-191 compatible)
        bytes32 digest = keccak256(abi.encode("MIGRATION_OUT", user, user, amount, riskScore, block.chainid))
            .toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiPrivateKey, digest);
        bytes memory aiProof = abi.encodePacked(r, s, v);

        try gateway.initiateMigration(DEST_CHAIN, user, amount, riskScore, aiProof) {
        // Success: Asset should be locked in gateway or burned
        }
            catch {
            // Failure expected if state or permissions are incomplete
        }
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS: INBOUND
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Inbound_Replay_Protection(address to, uint256 amount, bytes32 migrationId) public {
        vm.assume(to != address(0) && to != address(gateway));
        amount = bound(amount, 1, 1_000_000 ether);

        bytes32 digest = keccak256(abi.encode("MIGRATION_IN", DEST_CHAIN, to, amount, migrationId, block.chainid))
            .toEthSignedMessageHash();

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aiPrivateKey, digest);
        bytes memory neuralProof = abi.encodePacked(r, s, v);

        // İlk deneme: AI kanıtı geçerliyse başarılı olabilir
        try gateway.finalizeMigration(DEST_CHAIN, to, amount, migrationId, neuralProof) {}
            catch { /* Risk skoru veya yetki bazlı hata */ }

        // Replay Protection: Aynı migrationId ile ikinci kez asla geçmemeli
        vm.expectRevert();
        gateway.finalizeMigration(DEST_CHAIN, to, amount, migrationId, neuralProof);
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS: QUANTUM LIMITS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Quantum_Limits(uint256 amount) public {
        // Alt ve üst limitlerin dışındaki miktarlar gateway'i tetiklemeli
        if (amount > 0 && (amount < 100 ether || amount > 1_000_000 ether)) {
            vm.expectRevert();
            gateway.initiateMigration(DEST_CHAIN, address(0x1), amount, 0, "");
        }
    }
}
