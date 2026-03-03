// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console2} from "forge-std/Script.sol";
// Yolu remapping'e göre güncelledik
import {IAoxcCore} from "aoxc-interfaces/IAoxcCore.sol";

contract GlobalLock is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(pk);

        // Bu adres DeployFleet sonrasında güncellenecek
        address coreProxy = 0x74c7423D5ad0A3780c235000607e19f46d7D9EA5;

        console2.log(unicode"\n-------------------------------------------");
        console2.log(unicode"⚠️  AOXC EMERGENCY PROTOCOL: RULE 10");
        console2.log(unicode"-------------------------------------------");
        console2.log(unicode"Initiating Global System Lock...");
        console2.log(unicode"Operator Authority:", operator);

        vm.startBroadcast(pk);

        // Core Sistem Kilidini Aktif Etme
        IAoxcCore(coreProxy).setCoreLock(true);

        vm.stopBroadcast();

        console2.log(unicode"\n[!] STATUS: CORE SYSTEM LOCKED");
        console2.log(unicode"All Fleet Operations Suspended by AOXC Security Division.");
        console2.log(unicode"-------------------------------------------\n");
    }
}
