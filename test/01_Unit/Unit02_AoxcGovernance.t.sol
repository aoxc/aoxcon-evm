// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, console2} from "forge-std/Test.sol";
import {AoxcAuditVoice} from "aoxc/gov/AoxcAuditVoice.sol";
import {AoxcDaoManager} from "aoxc/gov/AoxcDaoManager.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/*//////////////////////////////////////////////////////////////
                        IDENTITY REGISTRY MOCK
//////////////////////////////////////////////////////////////*/

contract MockRegistry {
    struct CitizenRecord {
        uint256 citizenId;
        uint64 joinedAt;
        uint8 tier;
        uint256 reputation;
        uint64 lastPulse;
        uint256 totalVoted;
        bool isBlacklisted;
    }
    mapping(address => CitizenRecord) public citizenRecords;

    function setCitizen(address member, uint8 tier) external {
        citizenRecords[member] = CitizenRecord({
            citizenId: 1,
            joinedAt: uint64(block.timestamp),
            tier: tier,
            reputation: 100,
            lastPulse: uint64(block.timestamp),
            totalVoted: 0,
            isBlacklisted: false
        });
    }

    function getCitizenInfo(address member) external view returns (CitizenRecord memory) {
        return citizenRecords[member];
    }
}

/*//////////////////////////////////////////////////////////////
                        VOTES TOKEN MOCK
//////////////////////////////////////////////////////////////*/

contract MockVotesToken is ERC20, IVotes {
    mapping(address => mapping(uint256 => uint256)) private _historicalBalances;

    constructor() ERC20("AOX Coin", "AOXC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        _historicalBalances[to][block.number] = balanceOf(to);
    }

    function getPastVotes(address account, uint256 blockNumber) external view override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _historicalBalances[account][blockNumber];
    }

    function getPastTotalSupply(uint256 blockNumber) external view override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return totalSupply();
    }

    function delegates(address account) external pure override returns (address) {
        return account;
    }
    function delegate(address) external override {}
    function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) external override {}

    function getVotes(address account) external view override returns (uint256) {
        return balanceOf(account);
    }
}

/*//////////////////////////////////////////////////////////////
                        MAIN TEST SUITE
//////////////////////////////////////////////////////////////*/

contract GovernanceTest is Test {
    AoxcAuditVoice public auditVoice;
    AoxcDaoManager public daoManager;
    MockVotesToken public token;
    MockRegistry public registry;

    address admin = makeAddr("ADMIN");
    address nexus = makeAddr("NEXUS_HUB");
    address user1;
    uint256 user1Key = 0xA11CE;

    function setUp() public {
        vm.roll(100);
        token = new MockVotesToken();
        registry = new MockRegistry();
        user1 = vm.addr(user1Key);

        // 1. Audit Voice Proxy Deployment (Upgradeability Simulation)
        AoxcAuditVoice implementation = new AoxcAuditVoice();
        bytes memory initData = abi.encodeWithSelector(AoxcAuditVoice.initialize.selector, admin, nexus, address(token));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        auditVoice = AoxcAuditVoice(address(proxy));

        // 2. DAO Manager Deployment
        daoManager = new AoxcDaoManager(address(registry), address(token), 3 days);

        // 3. User Onboarding
        vm.label(user1, "Citizen_One");
        registry.setCitizen(user1, 2);
    }

    /*//////////////////////////////////////////////////////////////
                            STRESS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_VetoSignal_Otonom_Check() public {
        uint256 proposalId = 12345;
        token.mint(user1, 10000 * 1e18);

        // Flash-loan protection: must wait at least 1 block
        vm.roll(block.number + 1);

        vm.prank(user1);
        auditVoice.emitVetoSignal(proposalId);

        console2.log("Veto Signal: Success");
    }

    function test_FlashLoan_Prevention_Logic() public {
        uint256 proposalId = 999;
        token.mint(user1, 20000 * 1e18);

        // Roll yapmıyoruz! Aynı blokta oy kullanma denemesi REVERT etmeli.
        vm.expectRevert();
        vm.prank(user1);
        auditVoice.emitVetoSignal(proposalId);

        console2.log("Flash-loan prevention: Verified");
    }

    function test_DAO_Signature_Execution_Flow() public {
        address target = makeAddr("TARGET");
        uint256 value = 1 ether;
        vm.deal(address(daoManager), 10 ether);

        uint256 txIdx = daoManager.proposeAction(target, value, "");

        // User joins and stakes
        uint256 stakeAmount = 10000 * 1e18;
        token.mint(user1, stakeAmount);

        vm.startPrank(user1);
        token.approve(address(daoManager), stakeAmount);
        daoManager.joinAndStake(stakeAmount);
        vm.stopPrank();

        // Off-chain EIP-712 Signature Simulation
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = daoManager.nonces(user1);

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                daoManager.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(daoManager.CONFIRM_TYPEHASH(), txIdx, nonce, deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1Key, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Execute via Signature (Autonomous DAO Action)
        vm.prank(user1);
        daoManager.voteWithSignature(txIdx, deadline, signature);

        (,,,,, bool executed,) = daoManager.transactions(txIdx);
        assertTrue(executed, "Execution failed");
        assertEq(target.balance, 1 ether, "Balance mismatch");

        console2.log("Autonomous Signature Execution: Successful");
    }
}
