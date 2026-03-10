// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title AoxconXasToken
/// @notice AOXCON sisteminin ağlar arası akış tokenı.
contract AoxconXasToken is ERC20, AccessControl {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");

    string public walrusSchema;
    mapping(bytes32 => string) public walrusCidByRef;

    event BridgeSet(address indexed bridge);
    event WalrusSchemaUpdated(string schema);
    event WalrusCidSet(bytes32 indexed refId, string cid);

    constructor(address admin) ERC20("AOXCON XAS", "XAS") {
        require(admin != address(0), "XAS: ZERO_ADMIN");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(METADATA_ROLE, admin);
    }

    function setBridge(address bridge) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bridge != address(0), "XAS: ZERO_BRIDGE");
        _grantRole(BRIDGE_ROLE, bridge);
        emit BridgeSet(bridge);
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
}
