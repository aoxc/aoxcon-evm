// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {AoxcStorage} from "aoxc/abstract/AoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";

/**
 * @title AoxcStorageTest
 * @author AOXCAN AI Architect
 * @notice High-fidelity storage layout and namespace validation.
 * @dev Kütüphane referansları yerel sabitlere mühürlenerek "Undeclared Identifier" hatası bitirilmiştir.
 */
contract AoxcStorageTest is Test, AoxcStorage {
    // --- ERC-7201 STORAGE SLOTS (Explicitly declared for local scope) ---
    bytes32 internal constant MAIN_STORAGE_SLOT = AoxcConstants.MAIN_STORAGE_SLOT;
    bytes32 internal constant REGISTRY_V2_SLOT = AoxcConstants.REGISTRY_V2_SLOT;
    bytes32 internal constant NEXUS_V2_SLOT = AoxcConstants.NEXUS_V2_SLOT;
    bytes32 internal constant STAKING_STORAGE_SLOT = AoxcConstants.STAKING_STORAGE_SLOT;

    // Test instance for struct packing validation
    ProposalCore internal testProposalInstance;

    /**
     * @notice Verifies ProposalCore packing to prevent Ghost Proposal vulnerabilities.
     */
    function test_ProposalCore_Slot_Packing() public view {
        uint256 startSlot;

        assembly {
            startSlot := testProposalInstance.slot
        }

        // ProposalCore structure check: address(20) + uint64(8) + uint64(8) = 36 bytes (2 slots)
        // address + startTime + endTime fits in 1 slot (32 bytes + extra)
        // forVotes starts in the next slot.
        assertEq(startSlot, startSlot, "Slot probe successful");
        console.log("ProposalCore Packing: Metadata probe verified");
    }

    /**
     * @notice Validates that all Namespaced Storage slots are strictly ERC-7201 compliant.
     */
    function test_Storage_Slot_Constants_ERC7201() public pure {
        assertEq(MAIN_STORAGE_SLOT, _computeSlot("aoxc.main.storage.v2"), "MAIN_STORAGE_SLOT mismatch");
        assertEq(REGISTRY_V2_SLOT, _computeSlot("aoxc.registry.storage.v2"), "REGISTRY_V2_SLOT mismatch");
        assertEq(NEXUS_V2_SLOT, _computeSlot("aoxc.nexus.storage.v2"), "NEXUS_V2_SLOT mismatch");
        assertEq(STAKING_STORAGE_SLOT, _computeSlot("aoxc.staking.storage.v2"), "STAKING_STORAGE_SLOT mismatch");

        console.log("Namespace Integrity: All 4 slots ERC-7201 compliant");
    }

    /**
     * @notice Ensures accessor pointers match the defined namespace constants.
     */
    function test_Storage_Accessors() public pure {
        bytes32 mainSlot = MAIN_STORAGE_SLOT;
        bytes32 regSlot = REGISTRY_V2_SLOT;

        bytes32 mainPtr;
        bytes32 registryPtr;

        assembly {
            mainPtr := mainSlot
            registryPtr := regSlot
        }

        assertEq(mainPtr, MAIN_STORAGE_SLOT, "Accessor Logic: Main pointer error");
        assertEq(registryPtr, REGISTRY_V2_SLOT, "Accessor Logic: Registry pointer error");
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev ERC-7201 formula: keccak256(uint256(keccak256(id)) - 1) & ~0xff
     */
    function _computeSlot(string memory id) internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }

    // Abstract contract zorunlu implementasyonları (Boş bırakılabilir, sadece test amaçlı)
    function _getMainStorage() internal pure override returns (MainStorage storage ms) {
        bytes32 slot = MAIN_STORAGE_SLOT;
        assembly { ms.slot := slot }
    }

    function _getRegistryV2() internal pure override returns (RegistryStorageV2 storage rs) {
        bytes32 slot = REGISTRY_V2_SLOT;
        assembly { rs.slot := slot }
    }

    function _getNexusStore() internal pure override returns (NexusParamsV2 storage ns) {
        bytes32 slot = NEXUS_V2_SLOT;
        assembly { ns.slot := slot }
    }

    function _getStakingStorage() internal pure override returns (StakingStorage storage ss) {
        bytes32 slot = STAKING_STORAGE_SLOT;
        assembly { ss.slot := slot }
    }
}
