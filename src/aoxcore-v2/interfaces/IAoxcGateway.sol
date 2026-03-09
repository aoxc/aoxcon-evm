// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {IAoxcCore} from "./IAoxcCore.sol";

/**
 * @title IAoxcGateway
 * @author Aoxcore Security Architecture
 * @notice Autonomous Cross-Chain Migration ve Neural Vetting Arayüzü.
 * @dev V3.0: Köprü saldırılarını önlemek için 10-Noktalı Neural Handshake zorunlu kılar.
 */
interface IAoxcGateway {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MigrationInitiated(
        uint16 indexed dstChainId,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 migrationId,
        uint8 riskScore
    );

    event MigrationInFinalized(
        uint16 indexed srcChainId, 
        address indexed to, 
        uint256 amount, 
        bytes32 migrationId, 
        uint256 nonce
    );

    event NeuralAnomalyNeutralized(bytes32 indexed migrationId, uint8 riskScore, uint16 reasonCode);

    /*//////////////////////////////////////////////////////////////
                         MIGRATION OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Kural 1, 2, 3 & 7: AI risk kontrolü ile dışa transfer (outbound) başlatır.
     * @param dstChainId Hedef ağ ID'si.
     * @param to Hedef ağdaki alıcı adresi.
     * @param amount Transfer edilecek varlık miktarı.
     * @param packet Transfer yetkisini doğrulayan 10-noktalı handshake paketi.
     */
    function initiateMigration(
        uint16 dstChainId, 
        address to, 
        uint256 amount, 
        IAoxcCore.NeuralPacket calldata packet
    ) external payable;

    /**
     * @notice Kural 10: AI kriptografik kanıtı ile gelen (inbound) transferi tamamlar.
     * @param srcChainId Kaynak ağ ID'si.
     * @param to X Layer'daki alıcı adresi.
     * @param amount Gelen varlık miktarı.
     * @param migrationId Transferin benzersiz ID'si.
     * @param packet Gelen mesajın geçerliliğini onaylayan 10-noktalı handshake paketi.
     */
    function finalizeMigration(
        uint16 srcChainId,
        address to,
        uint256 amount,
        bytes32 migrationId,
        IAoxcCore.NeuralPacket calldata packet
    ) external;

    /*//////////////////////////////////////////////////////////////
                            GATEWAY ANALYTICS
    //////////////////////////////////////////////////////////////*/

    function getGatewayLockState() external view returns (bool isLocked, uint256 expiry);

    /**
     * @notice Transfer için gereken yerel (native) fee miktarını döndürür.
     */
    function quoteGatewayFee(uint16 dstChainId, uint256 amount) external view returns (uint256 nativeFee);

    /**
     * @notice Kural 3: Bir ağ için kalan 'Quantum' (likidite limiti) miktarını döndürür.
     */
    function getRemainingQuantum(uint16 chainId, bool isOutbound) external view returns (uint256 remaining);

    function isNetworkSupported(uint16 chainId) external view returns (bool);
    function migrationProcessed(bytes32 migrationId) external view returns (bool);

    /**
     * @notice Kural 9: Gateway protokolünün Core ile senkronize olup olmadığını doğrular.
     */
    function getGatewayProtocolHash() external view returns (bytes32);
}
