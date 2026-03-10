# AoxCore-XAS — Mütevazı Başlangıç, Sağlam Temel

Bu plan; gösterişten uzak, okunabilir ve güvenli bir inşa yaklaşımıyla hazırlanmıştır.
Ana fikir: **v1'i onur katmanı olarak koru, yeni ekonomik çekirdeği XAS ile kur, çok-zincir genişlemeyi bugünden sade tut.**

## Yeni Klasör Düzeni
- `src/aoxcore-xas/move/`
- `src/aoxcore-xas/solidity/`

Bu düzenin amacı; Move (Sui) ve Solidity (XLayer) kodlarını tek bir “XAS çekirdeği” altında toplamak ve modül yerleşimini sadeleştirmektir.

## Move Tarafı (Sui)
1. `honor_logic.move`
   - v1 doğrulanmış snapshot girdisinden `HonorXP` üretir.
   - transfer edilemeyen saygınlık katmanı sağlar.
   - governance için `governance_weight` çarpanı sunar.
2. `founder_vault.move`
   - v1 onur üyelerine kümülatif indeks ile sürekli teşekkür/ödül dağıtımı.
3. `auto_rebalancer.move`
   - Founder / XAS / Reserve dağılımını 10.000 BPS disiplininde uygular.
4. `neural_bridge.move`
   - deadline + finality buffer + nonce/replay + signer/proof onayı ile çift kontrollü köprü tüketimi.

## Solidity Tarafı (XLayer)
1. `AoxcXasToken.sol`
   - mesaj-idempotent `bridgeMint/bridgeBurn`.
2. `AoxcHonorVault.sol`
   - v1 founder ağırlığına göre gelir payı.
3. `AoxcDualVerifierBridge.sol`
   - finality + signer + pluggable proof verifier.
4. `AoxcVerifierRegistry.sol`
   - yarın Ada bağlandığında sadece yeni verifier ekleyebilmek için adapter kaydı.

## İnşa Prensipleri
- **Vefa:** v1 silinmez, satılamayan onur statüsüne dönüştürülür.
- **Sadelik:** her modül tek sorumluluk taşır.
- **Doğruluk:** replay/finality/nonce disiplininden taviz verilmez.
- **Genişleyebilirlik:** chain farkları verifier-adapter katmanında izole edilir.

## Sonuç
Henüz yolun başındayız. Bu yapı “nihai sistem” değil; ama gelecekteki güçlü mimarinin temiz, güvenli ve dürüst temeli olarak tasarlanmıştır.
