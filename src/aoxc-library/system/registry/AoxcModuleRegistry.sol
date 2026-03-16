// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Canonical registry for approved templates and deployed module instances.
contract AoxcModuleRegistry is Ownable {
    struct TemplateInfo {
        address implementation;
        bool approved;
        string version;
    }

    mapping(bytes32 => TemplateInfo) public templates;
    mapping(address => bool) public isRegisteredModule;
    mapping(address => bytes32) public moduleTypeOf;

    event TemplateUpdated(bytes32 indexed moduleType, address indexed implementation, bool approved, string version);
    event ModuleRegistered(address indexed module, bytes32 indexed moduleType);

    error InvalidImplementation();
    error UnknownTemplate();
    error ModuleAlreadyRegistered();

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setTemplate(bytes32 moduleType, address implementation, bool approved, string calldata version) external onlyOwner {
        if (approved && implementation == address(0)) revert InvalidImplementation();

        templates[moduleType] = TemplateInfo({implementation: implementation, approved: approved, version: version});
        emit TemplateUpdated(moduleType, implementation, approved, version);
    }

    function requireTemplate(bytes32 moduleType) external view returns (TemplateInfo memory info) {
        info = templates[moduleType];
        if (!info.approved || info.implementation == address(0)) revert UnknownTemplate();
    }

    function registerModule(address module, bytes32 moduleType) external onlyOwner {
        if (isRegisteredModule[module]) revert ModuleAlreadyRegistered();

        isRegisteredModule[module] = true;
        moduleTypeOf[module] = moduleType;
        emit ModuleRegistered(module, moduleType);
    }
}
