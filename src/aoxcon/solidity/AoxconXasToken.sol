// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

contract AoxconXasToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BRIDGE_MANAGER_ROLE = keccak256("BRIDGE_MANAGER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");

    address public activeBridge;
    string public walrusSchema;
    mapping(bytes32 refId => string cid) public walrusCidByRef;

    event BridgeRotated(address indexed previousBridge, address indexed newBridge);
    event WalrusSchemaUpdated(string schema);
    event WalrusCidSet(bytes32 indexed refId, string cid);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) external initializer {
        require(admin != address(0), "XAS: ZERO_ADMIN");

        __ERC20_init("AOXCON XAS", "XAS");
        __ERC20Permit_init("AOXCON XAS");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(BRIDGE_MANAGER_ROLE, admin);
        _grantRole(METADATA_ROLE, admin);
    }

    function rotateBridge(address newBridge) external onlyRole(BRIDGE_MANAGER_ROLE) {
        require(newBridge != address(0), "XAS: ZERO_BRIDGE");

        address previous = activeBridge;
        if (previous != address(0)) {
            _revokeRole(BRIDGE_ROLE, previous);
        }

        activeBridge = newBridge;
        _grantRole(BRIDGE_ROLE, newBridge);

        emit BridgeRotated(previous, newBridge);
    }

    function mintByBridge(address to, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        _mint(to, amount);
    }

    function burnByBridge(address from, uint256 amount) external onlyRole(BRIDGE_ROLE) {
        _burn(from, amount);
    }

    function setWalrusSchema(string calldata schema) external onlyRole(METADATA_ROLE) {
        walrusSchema = schema;
        emit WalrusSchemaUpdated(schema);
    }

    function setWalrusCid(bytes32 refId, string calldata cid) external onlyRole(METADATA_ROLE) {
        walrusCidByRef[refId] = cid;
        emit WalrusCidSet(refId, cid);
    }

    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
