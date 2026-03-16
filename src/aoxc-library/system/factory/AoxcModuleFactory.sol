// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IAoxcModule} from "aoxc-library/system/interfaces/IAoxcModule.sol";
import {AoxcModuleRegistry} from "aoxc-library/system/registry/AoxcModuleRegistry.sol";

/// @notice Factory that deploys approved module clones and records them in registry.
contract AoxcModuleFactory is Ownable {
    using Clones for address;

    AoxcModuleRegistry public immutable REGISTRY;

    event ModuleDeployed(bytes32 indexed moduleType, address indexed implementation, address indexed module, bytes32 salt);

    error InvalidRegistry();

    constructor(address initialOwner, address registry_) Ownable(initialOwner) {
        if (registry_ == address(0)) revert InvalidRegistry();
        REGISTRY = AoxcModuleRegistry(registry_);
    }

    function deployModule(bytes32 moduleType, bytes32 salt, bytes calldata initData) external onlyOwner returns (address module) {
        AoxcModuleRegistry.TemplateInfo memory info = REGISTRY.requireTemplate(moduleType);

        module = info.implementation.cloneDeterministic(salt);
        IAoxcModule(module).initialize(initData);

        REGISTRY.registerModule(module, moduleType);
        emit ModuleDeployed(moduleType, info.implementation, module, salt);
    }

    function predictModuleAddress(bytes32 moduleType, bytes32 salt) external view returns (address) {
        AoxcModuleRegistry.TemplateInfo memory info = REGISTRY.requireTemplate(moduleType);
        return info.implementation.predictDeterministicAddress(salt, address(this));
    }
}
