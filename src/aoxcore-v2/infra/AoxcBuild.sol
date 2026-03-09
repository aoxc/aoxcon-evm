// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title AoxcBuild (Neural Prime V3.2)
 * @author AOXCAN Infrastructure Division
 * @notice Enterprise-grade asset factory with Soulbound Identity and Neural Cell mapping.
 * @dev V2.0.0 Genesis Standard: Resolves diamond inheritance and enforces Neural Gating.
 */

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// AOXC INTERNAL INFRASTRUCTURE
import {IAoxcBuild} from "aoxc-interfaces/IAoxcBuild.sol";
import {IAoxcAutoRepair} from "aoxc-interfaces/IAoxcAutoRepair.sol";
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";
import {AoxcStorage} from "aoxc-abstract/AoxcStorage.sol";
import {AoxcConstants} from "aoxc-libraries/AoxcConstants.sol";
import {AoxcErrors} from "aoxc-libraries/AoxcErrors.sol";
import {AoxcEvents} from "aoxc-libraries/AoxcEvents.sol";



contract AoxcBuild is
    IAoxcBuild,
    IAoxcAutoRepair,
    Initializable,
    UUPSUpgradeable,
    AccessManagerUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable,
    AoxcStorage
{
    using Strings for uint256;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public core; 
    string public baseAssetURI;
    address public aiNode;
    address public auditVoice;
    uint256 public nextAssetId;
    bool public globalCircuitBreaker;

    mapping(uint256 => bool) public anomalyLedger;
    mapping(bytes4 => bool) public isReserved;
    mapping(address => uint256) public lastActionNonce;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyActive() {
        if (globalCircuitBreaker) revert AoxcErrors.Aoxc_GlobalLockActive();
        _;
    }

    modifier neuralGated(IAoxcCore.NeuralPacket calldata packet) {
        if (!IAoxcCore(core).executeNeuralAction(packet)) {
            revert AoxcErrors.Aoxc_Neural_SecurityVeto(msg.sender, packet.riskScore);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                               INITIALIZER
    //////////////////////////////////////////////////////////////*/

    function initializeBuildV3(
        address admin, 
        address _core,
        string memory uri, 
        address aiNode_, 
        address auditVoice_
    ) external initializer {
        if (admin == address(0) || _core == address(0)) revert AoxcErrors.Aoxc_InvalidAddress();

        __AccessManager_init(admin);
        __ERC721_init("Aoxc Universal Assets", "AOX-X");
        __ReentrancyGuard_init();

        core = _core;
        nextAssetId = 1;
        baseAssetURI = uri;
        aiNode = aiNode_;
        auditVoice = auditVoice_;

        isReserved[this.liftQuarantine.selector] = true;
        isReserved[this.executePatch.selector] = true;
    }

    /*//////////////////////////////////////////////////////////////
                        PRODUCTION (IAoxcBuild)
    //////////////////////////////////////////////////////////////*/

    function buildAsset(
        address to, 
        AssetType aType, 
        bytes32 doc, 
        uint256 initialVal,
        IAoxcCore.NeuralPacket calldata packet 
    ) external override onlyActive neuralGated(packet) returns (uint256 assetId) {
        _checkAoxcRole(AoxcConstants.GUARDIAN_ROLE);

        RegistryStorageV2 storage s = _getRegistryV2();
        if (aType == AssetType.IDENTITY && s.citizenRecords[to].citizenId != 0) {
            revert AoxcErrors.Aoxc_CustomRevert("BUILD: IDENTITY_ALREADY_EXISTS");
        }

        assetId = 1000 + nextAssetId++;

        s.assets[assetId] = SovereignAsset({
            assetId: assetId,
            aType: aType,
            tokenAddress: address(this),
            totalMinted: initialVal,
            reserveRatio: 0,
            isMintingActive: true,
            docHash: doc
        });

        if (aType == AssetType.IDENTITY) _onboardCitizen(to, assetId, packet.riskScore);

        _safeMint(to, assetId);
        
        // FIX: Enum explicit cast uint8(aType) eklenerek Error (9553) çözüldü.
        emit AoxcEvents.AssetBuilt(to, assetId, uint8(aType), packet.riskScore);
    }

    /*//////////////////////////////////////////////////////////////
                        REPAIR ENGINE INTERFACE
    //////////////////////////////////////////////////////////////*/

    function executePatch(
        uint256 anomalyId,
        bytes4 selector,
        address target,
        address patchLogic,
        IAoxcCore.NeuralPacket calldata packet
    ) external override(IAoxcBuild, IAoxcAutoRepair) onlyActive neuralGated(packet) {
        _checkAoxcRole(AoxcConstants.GOVERNANCE_ROLE);
        anomalyLedger[anomalyId] = true;
        
        emit AoxcEvents.PatchExecuted(selector, target, patchLogic);
    }

    function triggerEmergencyQuarantine(
        bytes4 selector, 
        address target,
        IAoxcCore.NeuralPacket calldata packet
    ) external override(IAoxcBuild, IAoxcAutoRepair) nonReentrant neuralGated(packet) {
        _getRegistryV2().activePatches[selector][target].isQuarantined = true;
        emit AoxcEvents.SystemRepairInitiated(keccak256(abi.encodePacked(selector, target)), target);
    }

    function liftQuarantine(
        bytes4 selector, 
        address target,
        IAoxcCore.NeuralPacket calldata packet
    ) external override(IAoxcBuild, IAoxcAutoRepair) onlyActive neuralGated(packet) {
        if (msg.sender != auditVoice && !_hasSovereignRole(AoxcConstants.GUARDIAN_ROLE, msg.sender)) {
            revert AoxcErrors.Aoxc_CustomRevert("REPAIR: ACCESS_DENIED");
        }
        delete _getRegistryV2().activePatches[selector][target];
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isOperational(bytes4 selector) external view override(IAoxcAutoRepair) returns (bool) {
        return !globalCircuitBreaker && !_getRegistryV2().activePatches[selector][address(this)].isQuarantined;
    }

    function getRepairStatus() external view override(IAoxcAutoRepair) returns (bool inRepairMode, uint256 expiry) {
        MainStorage storage m = _getMainStorage();
        return (m.isRepairModeActive, m.repairExpiry);
    }

    function validatePatch(uint256 anomalyId) external view override(IAoxcAutoRepair) returns (bool isVerified) {
        return anomalyLedger[anomalyId];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function _onboardCitizen(address to, uint256 assetId, uint8 riskScore) internal {
        RegistryStorageV2 storage s = _getRegistryV2();
        s.citizenRecords[to] = CitizenRecord({
            citizenId: assetId,
            joinedAt: uint64(block.timestamp),
            tier: 1,
            reputation: 100,
            lastPulse: uint64(block.timestamp),
            totalVoted: 0,
            isBlacklisted: false,
            blacklistReason: ""
        });
        _assignToCell(to);
        
        // FIX: Parametre uyumu sağlandı.
        emit AoxcEvents.MemberOnboarded(to, assetId, riskScore);
    }

    function _assignToCell(address member) internal {
        RegistryStorageV2 storage s = _getRegistryV2();
        uint256 currentCellId = s.totalCells == 0 ? _spawnCell() : s.totalCells;
        if (s.cells[currentCellId].memberCount >= AoxcConstants.MAX_CELL_MEMBERS) {
            currentCellId = _spawnCell();
        }
        s.userToCellMap[member] = currentCellId;
        s.cells[currentCellId].memberCount++;
    }

    function _spawnCell() internal returns (uint256 id) {
        RegistryStorageV2 storage s = _getRegistryV2();
        id = ++s.totalCells;
        s.cells[id] = NeuralCellV2({
            cellId: id,
            cellHash: keccak256(abi.encodePacked(block.timestamp, id, s.lastCellHash)),
            memberCount: 0,
            isQuarantined: false,
            lockExpiry: 0
        });
        s.lastCellHash = s.cells[id].cellHash;
        emit AoxcEvents.CellSpawned(id, s.lastCellHash, id > 1 ? s.cells[id - 1].cellHash : bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                            CORE OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0) && (tokenId < 1100)) {
            revert AoxcErrors.Aoxc_CustomRevert("SBT: NON_TRANSFERABLE_IDENTITY");
        }
        return super._update(to, tokenId, auth);
    }

    function _authorizeUpgrade(address) internal view override {
        _checkAoxcRole(AoxcConstants.UPGRADER_ROLE);
    }

    function _hasSovereignRole(bytes32 role, address account) internal view returns (bool) {
        (bool isMember,) = hasRole(uint64(uint256(role)), account);
        return isMember;
    }

    function _checkAoxcRole(bytes32 role) internal view {
        if (!_hasSovereignRole(role, msg.sender)) revert AoxcErrors.Aoxc_Unauthorized(role, msg.sender);
    }

    uint256[50] private __gap;
}
