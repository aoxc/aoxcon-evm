// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script, console2} from "forge-std/Script.sol";
// Yolu remapping'e göre güncelledik
import {IAoxcRegistry} from "aoxc-interfaces/IAoxcRegistry.sol";

contract SyncFleet is Script {
    /**
     * @dev DİKKAT: Bu adresler bir önceki 'DeployFleet' scriptinden
     * aldığın Proxy adresleri olmalıdır.
     */
    address constant REGISTRY_PROXY = 0xD3Baa551eed9A3e7C856A5F87A0EA0361a24C076;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address operator = vm.addr(pk);

        console2.log(unicode"\n-------------------------------------------");
        console2.log(unicode"🔗 AOXC FLEET SYNCHRONIZATION SEQUENCE");
        console2.log(unicode"-------------------------------------------");
        console2.log(unicode"Operator:", operator);

        vm.startBroadcast(pk);

        IAoxcRegistry registry = IAoxcRegistry(REGISTRY_PROXY);

        // Modülleri Filo Siciline (Registry) Kaydetme
        console2.log(unicode"\n[1/4] Registering NEXUS...");
        registry.onboardMember(0x3dA95dB23aa88e5Aa0c5F5Cf9a765D56395b10d0);

        console2.log(unicode"[2/4] Registering VAULT...");
        registry.onboardMember(0xAFc060Fd5Eb8249A99Fb135f73456eD7708A710d);

        console2.log(unicode"[3/4] Registering SENTINEL...");
        registry.onboardMember(0x59A85fb33e122B96086721388B3b0e909ab1aA3D);

        console2.log(unicode"[4/4] Registering CORE...");
        registry.onboardMember(0x74c7423D5ad0A3780c235000607e19f46d7D9EA5);

        vm.stopBroadcast();

        console2.log(unicode"\n-------------------------------------------");
        console2.log(unicode"✅ STATUS: FLEET SYNCHRONIZED & SOVEREIGN");
        console2.log(unicode"All modules linked to Registry.");
        console2.log(unicode"-------------------------------------------\n");
    }
}
