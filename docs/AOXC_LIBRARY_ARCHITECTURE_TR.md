# AOXC Library Mimarisi (V1 bağımsız, V2 modüler)

Bu düzenlemede proje, tüketicilerin hızlı entegre edebilmesi için **modül odaklı bir kütüphane yüzeyi** sunar.

## Amaç
- V1'i şimdilik upgrade akışından ayırmak.
- V2 kontratlarını tür bazlı modüller halinde sunmak (hazine, ai, stake, bridge, governance, access, infra, core).
- İleride V1 eklenecekse aynı şemayla `src/aoxc-library/v1/...` altına eklenebilmesini sağlamak.

## Klasör şeması
- `src/aoxc-library/core`
- `src/aoxc-library/treasury`
- `src/aoxc-library/ai`
- `src/aoxc-library/stake`
- `src/aoxc-library/bridge`
- `src/aoxc-library/access`
- `src/aoxc-library/governance`
- `src/aoxc-library/infra`

Bu dizinlerdeki `*Module.sol` dosyaları mevcut V2 sözleşmelerine ince bir kütüphane giriş katmanı sağlar.

## Tüketici kullanım örneği
```solidity
import {AoxcVaultModule} from "aoxc-lib-treasury/AoxcVaultModule.sol";
import {AoxcSentinelAIModule} from "aoxc-lib-ai/AoxcSentinelAIModule.sol";
```

## Not
- Bu adım kırıcı taşımadan kaçınır; mevcut `src/aoxcore-v2` yerleşimi korunur.
- Sonraki adımda istenirse fiziksel dosya taşıma yapılabilir.
