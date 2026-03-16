# AOXC V1/V2 Upgrade Yapısını Kütüphane Gibi Ayrıştırma (Öneri)

Bu repo içinde **V1 ve V2'yi tamamen taşımadan**, önce güvenli bir şekilde "kütüphane gibi tüketilebilir" hale getirmek için aşağıdaki yaklaşım önerilir.

## Kısa cevap
Evet, mümkün.

- V1 ve V2'yi bağımsız modüller gibi yayınlayabilirsiniz.
- Foundry remapping alias'ları ile dış projeler sadece ihtiyaç duyduğu versiyonu import eder.
- Fiziksel büyük taşıma (dosya taşıma/yeniden adlandırma) tek adımda yapılırsa kırıcı olabilir; bunu aşamalı yapmak daha güvenli.

## Bu PR ile atılan adım
- `foundry.toml` içine aşağıdaki alias'lar eklendi:
  - `upgrade-v1/=src/aoxcore-v1/`
  - `upgrade-v2/=src/aoxcore-v2/`
  - `upgrade-honor/=src/aoxcon/solidity/`

Bu sayede dışarıdan şu şekilde import yapılabilir:

```solidity
import {AOXC} from "upgrade-v1/AOXC.sol";
import {AoxcCore} from "upgrade-v2/core/AoxcCore.sol";
```

## Hedef klasörleme (aşamalı)
Aşağıdaki hedef yapı önerilir:

- `src/upgrade/v1/...`
  - `treasury/`
  - `ai/`
  - `stake/`
  - `bridge/`
- `src/upgrade/v2/...`
  - `treasury/`
  - `ai/`
  - `stake/`
  - `bridge/`

Ancak öneri: önce alias ile dış API'yi stabil hale getirip, sonra içeride taşıma yapmak.

## Neden bağımsız kullanım mümkün?
- V1/V2'nin namespace'i remapping ile ayrılıyor.
- Derleyici düzeyinde import yolları izole ediliyor.
- İstenirse sonra her versiyon ayrı package/repo olarak da çıkarılabilir.

## Dikkat edilmesi gerekenler
1. Upgrade storage layout kontratları taşınırken import path değişimi yüzünden dikkatli olun.
2. Script/test/import yolları için toplu refactor + compile/test pipeline gerekir.
3. `flat/` artefaktları kaynak gerçekliğiyle birebir tutulmalı (placeholder değil).

## Önerilen sıradaki adım
1. Alias'ları tüm script/test'te kullanıma almak.
2. "Tür bazlı" klasörlere taşıma için bir migration branch açmak.
3. Her klasör taşıma adımında `forge build && forge test` ile güvence almak.
4. Son aşamada V1/V2 bağımsız paketleme (ayrı git module/repo) değerlendirmek.
