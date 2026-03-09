# AOXCORE Frontend Hata Analizi (v1 → v2 Geçişi)

## 1) Amaç ve Kapsam

Bu rapor; AOXCORE frontend katmanında **v1’den v2’ye geçişte** ortaya çıkan hata desenlerini, kök nedenleri, operasyonel riskleri ve iyileştirme planını derler.

Analiz kapsamı:
- Geçiş uyumluluğu (v1/v2) ve göç hazırlığı
- Frontend derleme/typing/lint kırılımları
- Çevresel (environment) bağımlılık kaynaklı blokajlar
- Kısa, orta ve uzun vadeli geliştirme planı

---

## 2) Hızlı Özet (Executive Summary)

1. **Kritik blokaj**: Frontend bağımlılıkları kurulu değil veya çözülmüyor; bu yüzden TypeScript çözümleyicisi temel paketleri (`react`, `framer-motion`, `react/jsx-runtime` vb.) bulamıyor.
2. **Paket yönetimi tutarsızlığı**: Repoda hem `yarn.lock` hem `.pnp.cjs/.pnp.loader.mjs` bulunması, buna karşılık `node_modules` altında yalnızca Vite cache yapısı olması; ortamın Yarn PnP ile klasik node_modules beklentisi arasında kararsız kaldığını gösteriyor.
3. **Ağ/politika engeli**: `npm install` sırasında `@google/genai` paketi için `403 Forbidden` alındığı için bağımlılıklar tam kurulamadı.
4. **Kod kalitesi düzeyi**: Bağımlılıklar çözülmeden görünen TypeScript hata seli içinde gerçek uygulama-hataları seçilemez hale geliyor. Önce kurulum/registry/paket yönetimi stabil hale getirilmeli.
5. **Protokol tarafı güven göstergesi**: Storage slot doğrulama betiği başarıyla geçti; bu, v1→v2 geçiş güvenliği için çekirdek seviyede olumlu sinyal.

---

## 3) Bulgular — Frontend Hata Envanteri

### 3.1 Derleme/Type Hatalarının Ana Sınıfı

`npm run type-check` çıktısında baskın hata sınıfı:
- `TS2307: Cannot find module ...`
- `TS2875: react/jsx-runtime bulunamadı`

Etkisi:
- Uygulama kodunun semantik doğrulaması yapılamıyor.
- Tip güvenliği ve CI kalitesi pratikte devre dışı kalıyor.

### 3.2 Çevresel Kurulum Çatışması

Gözlenen durum:
- `package.json` içinde scriptler npm tabanlı (`npm run type-check`, `npm run build`)
- Repoda Yarn PnP işaretleri mevcut (`.pnp.cjs`, `.pnp.loader.mjs`, `yarn.lock`)
- `node_modules` içinde gerçek paketler yok (yalnızca `.vite` cache)

Yorum:
- Frontend çalışma modeli tek bir standarda kilitlenmemiş.
- Geliştirici makinesi/CI arasında “çalışıyor-bende” farkı üretme riski yüksek.

### 3.3 Registry/Policy Kaynaklı Kurulum Hatası

`npm install` çıktısı:
- `E403 / 403 Forbidden - GET https://registry.npmjs.org/@google%2fgenai`

Yorum:
- Sorun doğrudan kaynak koddan çok **registry erişim politikası** ve/veya sürüm izinleriyle ilişkili.
- Bu çözülmeden frontend kalite kapıları (type-check/lint/build) anlamlı şekilde çalıştırılamaz.

---

## 4) v1 → v2 Geçiş Analizi ile Frontend Bağlantısı

Mevcut parity dokümanında v1/v2 token çekirdeği için:
- UUPS, blacklist, transfer limitleri, günlük limit, mint sınırları gibi başlıklarda yüksek hizalanma var.
- `rescueERC20` için halen “gap” işaretlenmiş.
- “Migration ready” kriterleri storage slot kontrolü + parity testleri + partial/gap konularında runbook/karar zorunluluğu içeriyor.

Frontend tarafına etkisi:
1. **Operasyon paneli ve uyarı dili**, parity dokümanındaki “partial/gap” alanlarını operatöre görünür kılmalı.
2. **Geçiş ekranları** (upgrade panel, status matrix vb.) sadece “başarılı/başarısız” değil, “waived gap / governance override / pending role-map” gibi durumları da taşımalı.
3. Frontend kalite kapıları kırık kaldığında, migration rehearsal görünürlüğü düşer ve hatalı güven hissi oluşur.

---

## 5) Kök Neden Analizi (RCA)

### RCA-1: Paket yönetimi standardı net değil
- Belirti: npm scriptleri + Yarn PnP dosyaları + eksik node_modules.
- Sonuç: Toolchain, farklı ortamlarda farklı çözümleme davranışı sergiliyor.

### RCA-2: Kurumsal registry/paket erişim politikası
- Belirti: `@google/genai` kurulumunda 403.
- Sonuç: Tam bağımlılık kurulamadığı için zincirleme TS hata üretimi.

### RCA-3: Kalite kapılarının katmanlı çalışmaması
- Belirti: “dependency resolution fail” durumunda binlerce “cannot find module” çıkışı.
- Sonuç: Gerçek uygulama bug’ları görünmez kalıyor, debug maliyeti artıyor.

### RCA-4: Geçiş telemetrisi ile UI mesajlarının bağının zayıf olması
- Belirti: Teknik parity durumu dokümanda; UI tarafında aynı olgunlukta durum kodları net değil.
- Sonuç: Operasyonel karar alma süresi uzar.

---

## 6) Risk Değerlendirmesi

| Risk | Seviye | Etki | Olasılık | Not |
|---|---|---|---|---|
| Frontend’in type-check/build aşamasında blok kalması | Yüksek | Yüksek | Yüksek | Kurulum kırıkken release güveni yok |
| CI ve lokal ortamın farklı davranması | Yüksek | Orta-Yüksek | Yüksek | PnP vs node_modules belirsizliği |
| Migration UI’nin parity boşluklarını taşımaması | Orta | Yüksek | Orta | Operatör karar kalitesi düşer |
| “Gap” başlıklarının governance kararı olmadan üretime taşınması | Orta | Yüksek | Orta | v2 fonksiyonel kapsam yanlış anlaşılır |

---

## 7) Aksiyon Planı (Full Gelişim Planı)

### Faz-0 (Acil / 0-1 gün)
1. **Paket yöneticisini tekleştir**: `npm` veya `yarn(pnp/node-modules)` net kararı al.
2. **Registry erişimini düzelt**: `@google/genai` için 403 kaynağını çöz (token, mirror, allowlist, policy).
3. **Bağımlılık doğrulama kapısı ekle**: type-check öncesi `react`/`typescript`/`vite` çözümleme testi.

### Faz-1 (Stabilizasyon / 1-3 gün)
1. `npm run type-check`, `npm run lint`, `npm run build` üçlüsünü yeşile çek.
2. Geçiş ekranlarında v1/v2 parity durum kodlarını (aligned/partial/gap/waived) görünürleştir.
3. Frontend error boundary + telemetri kanalını migration olaylarıyla ilişkilendir.

### Faz-2 (Kalıcı İyileştirme / 3-7 gün)
1. CI’da “dependency-resolve” ayrı stage: başarısızsa hızlı fail + anlaşılır log.
2. “Migration rehearsal” çıktılarının frontend dashboard’a bağlanması.
3. Dokümantasyon standardı: frontend release checklist içine parity doğrulama adımı ekleme.

### Faz-3 (Olgunluk / 1-2 sprint)
1. SLI/SLO: type-check süresi, build başarısı, migration panel doğruluk metriği.
2. Frontend observability: hata kodu sınıfları + correlation id.
3. V1→V2 RC karar kapısı: teknik + ürün + governance ortak onayı.

---

## 8) Teknik Doğrulama Notları

Bu analiz sırasında gözlenen komut çıktıları:
- `python3 script/check_storage_slots.py` → başarılı (`[OK] Unique storage slot constants ...`).
- `npm run type-check` (frontend) → başarısız, çok sayıda modül bulunamadı hatası.
- `npm install` (frontend) → `@google/genai` için `403 Forbidden`.

---

## 9) Sonuç

Frontend tarafındaki temel problem, uygulama kodundan önce **bağımlılık çözümleme ve paket yönetimi standardizasyonu**dur. Bu katman stabil hale getirilmeden v1→v2 geçişine ilişkin UI güvenilirliği ve operasyonel doğruluk tam sağlanamaz. Storage-slot güven göstergesinin pozitif olması, çekirdek tarafta iyi bir başlangıçtır; ancak frontend kalite kapılarının tekrar çalışır hale gelmesi kritik önceliktir.
