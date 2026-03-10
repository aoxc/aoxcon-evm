# AOXCORE XLayer + Sui Yol Haritası (Legacy Honor + Universal Expansion)

## Amaç
Bu plan, **v1 AOXC token mirasını silmeden onurlandırmak**, mevcut v2 altyapısını daha güvenli bir yükseltme hattına taşımak ve eş zamanlı olarak Sui + (ileride) Cardano uyumlu yeni nesil bir çok-zincir stratejisi başlatmak için hazırlanmıştır.

Temel ilke:
- **v1 yok edilmez, statüye dönüştürülür** (Honor/XP).
- **v2 acele “replace” edilmez, hardening + migration-first** yaklaşımıyla iyileştirilir.
- **Yeni omni-chain varlık (AOXC-XAS)**, “sıfırdan tasarım” prensibiyle Sui ve XLayer’da kanıta dayalı birlikte çalışır.

---

## 1) v1 için “Legacy Honor Layer”

### 1.1 Hedef
v1 holder’ları sistem dışına itmeden, onları protokolün “kurucu payı / onur katmanı” olarak kalıcı bir role taşımak.

### 1.2 Uygulama Çerçevesi

#### XLayer tarafı (Solidity)
- `HonorVault` modeli:
  - v1 snapshot köküne (Merkle root) dayalı hak sahipliği doğrulaması.
  - Protokol gelirinden ayrılan payın claim edilebilir hale getirilmesi.
  - Çifte talebi (double-claim) engelleyen claim bitmap.
- `AoxcBridgeVerifier` üzerinden domain ayrıştırmalı `HONOR_SYNC` event akışı.

#### Sui tarafı (Move)
- `reputation.move` benzeri modülde:
  - `HonorXP` kaydı.
  - v1 bakiyesine bağlı “Makam çarpanı”.
  - DAO oylamasında ayrı katsayı kuralı (ör: `vote_power = base + honor_multiplier`).

### 1.3 Risk Kontrolleri
- Honor puanı transfer edilemez (soulbound mantık).
- Sadece doğrulanmış snapshot dönemleri için claim açılır.
- Governance ile güncellenebilir ama geri tarihli oynama yapılamaz.

---

## 2) v2 için “Upgrade-in-Place Hardening”

### 2.1 Neden “yeniye zıpla” değil?
Repo’da hâlihazırda güçlü v2 bileşenleri (`core`, `finance`, `bridge`, `infra`) bulunduğu için teknik borcu azaltan en doğru yol:
1. storage güvenliği,
2. bridge doğrulama,
3. operasyonel görünürlük,
4. migration provasını
sıkılaştırmaktır.

### 2.2 v2 Hardening Backlog (Öncelik Sırası)
1. **Bridge replay/deadline guard** sertleştirmesi.
2. **Invariant test genişlemesi** (`V1ToV2MigrationUpgrade`, `V1V2Parity` kapsam artışı).
3. **Storage slot drift gate** CI zorunlu adımı.
4. **Sentinel otomatik onarım sınırları** (policy + rate-limit).
5. **Runbook standardizasyonu** (incident + rollback + rehearse).

### 2.3 Başarı Kriteri
- v1→v2 migrasyonunda bakiye, yetki, zaman kilidi ve event parity kaybı olmamalı.
- Bridge tarafında nonce tekrarında kesin revert.
- 1 tıkta “emergency stop + controlled repair” akışı denetlenebilir olmalı.

---

## 3) AOXC-XAS: Yeni Nesil Omni-Chain Varlık

### 3.1 Konumlandırma
AOXC-XAS, v1’in yerine “silici” bir token değil; v1’i onurlandıran ve ileriye taşıyan egemen işlem anahtarıdır.

### 3.2 Tasarım Prensipleri
- **Atomic Mint/Burn:** XLayer ve Sui arasında mint-burn mesajları tekil `messageId` ile idempotent.
- **Storage-agnostic:** Ağır metadata ve geçmiş Walrus CID ile dışarıda; zincirde sadece hash/pointer.
- **Proof-first accounting:** Her cross-chain eylemde kanıt kimliği zorunlu.

### 3.3 Token Model Önerisi
- `AOXC` (v1): Honor/XP kaynağı (prestij + governance çarpanı).
- `AOXC-XAS` (yeni): likidite, ödeme, utility ve cross-chain settlement tokenı.
- Çatışmayı önlemek için fonksiyonel ayrım net tutulur.

---

## 4) Sui Yerleşimi ve Kanıt Katmanı

### 4.1 Sovereign Settlement
- XLayer’daki kritik işlemler, Sui’de “finality record” olarak mühürlenir.
- İlk fazda imzalı attestasyon + replay koruması.
- İkinci fazda light client/committee proof.
- Üçüncü fazda ZKP doğrulama.

### 4.2 Walrus Kalıcı Geçmiş
- Tüm operasyon geçmişi için CID tabanlı değiştirilemez günlük.
- Her kayıtta: `domain`, `nonce`, `payloadHash`, `walrusCid`, `timestamp`.
- Denetimde zincir dışı veri ile zincir üstü hash birebir doğrulanır.

---

## 5) Cardano için “Expansion Slot”

### 5.1 Plug-in Verifier Registry
- `verifier_registry` benzeri tak-çıkar kayıt yapısı:
  - her yeni zincir için `chainId => verifierAdapter`.
  - mevcut akış bozulmadan yeni doğrulayıcı ekleme.
- eUTXO farkları adapter katmanında soyutlanır.

### 5.2 Kural
- Çekirdek iş mantığı zincirden bağımsız kalır.
- Sadece adapter/verifier eklentisi zincir spesifik olur.

---

## 6) 90 Günlük Önerilen İcra Planı

### Faz-1 (Gün 0-30)
- v1 snapshot + HonorVault tasarımının dondurulması.
- v2 hardening testlerinin genişletilmesi.
- Sui tarafında `HonorXP` kayıt şemasının netleştirilmesi.

### Faz-2 (Gün 31-60)
- AOXC-XAS mint/burn mesaj şemasının versiyonlanması.
- Walrus CID + hash mühür akışının devreye alınması.
- Replay/deadline güvenlik testleri + saldırı senaryoları.

### Faz-3 (Gün 61-90)
- verifier registry ile Cardano adapter “boş slot” hazırlanması.
- Canary ortamında uçtan uca migration rehearsal.
- Governance onayı sonrası kademeli üretim açılışı.

---

## 7) “Farklı ama kopuk olmayan” strateji önerim
1. **Mirası statüye çevir, ekonomiyi yeni tokenda kur.**
2. **v2’yi çöpe atma; önce güvenceyi artır, sonra genişlet.**
3. **Sui’yi sadece hız için değil, doğrulama ve arşiv katmanı için kullan.**
4. **Cardano’yu bugünden kodlamak yerine adaptör kontratıyla yer aç.**
5. **Tek cümle prensip:** “Legacy Honor + Universal Expansion + Proof-First Security.”

Bu yaklaşım, topluluğa “eskiye saygı” verirken teknik ekip için sürdürülebilir ve denetlenebilir bir çok-zincir büyüme zemini sağlar.
