// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AoxcNexus} from "aoxc-v2/core/AoxcNexus.sol";
import {AoxcCore} from "aoxc-v2/core/AoxcCore.sol"; // Mock yerine gerçeği kullanıyoruz
import {AoxcConstants} from "aoxc-v2/libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-v2/libraries/AoxcErrors.sol";

contract AoxcNexusTest is Test {
    AoxcNexus public nexus;
    AoxcCore public token;

    address admin = makeAddr("admin");
    address auditVoice = makeAddr("ai_audit");
    address voter = makeAddr("voter");
    bytes32 integrityHash = keccak256("AOXC_V2_GENESIS");

    function setUp() public {
        // 1. Önce Token (Core) Deployment
        AoxcCore tokenImpl = new AoxcCore();
        bytes memory tokenInit = abi.encodeWithSelector(
            AoxcCore.initializeV2.selector,
            address(0), address(this), address(0), address(0), admin, integrityHash
        );
        token = AoxcCore(address(new ERC1967Proxy(address(tokenImpl), tokenInit)));

        // 2. Sonra Nexus Deployment
        AoxcNexus nexusImpl = new AoxcNexus();
        bytes memory nexusInit = abi.encodeWithSelector(
            AoxcNexus.initializeNexusV2.selector,
            admin, auditVoice, address(token)
        );
        nexus = AoxcNexus(address(new ERC1967Proxy(address(nexusImpl), nexusInit)));
        
        // 3. Voter Hazırlığı
        vm.startPrank(admin);
        token.grantRole(AoxcConstants.GOVERNANCE_ROLE, admin);
        token.mint(voter, 1000 * 1e18);
        vm.stopPrank();

        vm.prank(voter);
        token.delegate(voter); // Şimdi çalışacak!
        
        vm.roll(block.number + 1); 
    }

    function test_Propose_And_NeuralVeto() public {
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(0x123);
        calldatas[0] = "";
        
        IAoxcCore.NeuralPacket memory packet;
        packet.riskScore = 50;

        uint256 proposalId = nexus.propose(targets, values, calldatas, "Upgrade Protocol", packet);
        
        // Veto İşlemi
        packet.riskScore = 250; 
        vm.prank(auditVoice);
        nexus.processNeuralVeto(proposalId, packet);

        assertEq(uint(nexus.state(proposalId)), uint(IAoxcNexus.ProposalState.NeuralVetoed));
        console.log(">> AI Veto Success. Proposal Defeated by Neural Layer.");
    }
}
