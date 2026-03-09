# AOXCORE v1 (`AOXC.sol`) → v2 (`AoxcCore.sol`) Deploy Readiness Analizi (TR)

## Sonuç (Kısa Cevap)

Şu anki repo durumuna göre **production yükseltme için GO veremem**. En doğru karar: **NO-GO**.

Ana nedenler:
1. `AoxcCore.sol` içinde derlemeyi kıracak seviyede bozulmuş/çakışmalı kod izleri var (tekrarlanan constant tanımları, duplicate fonksiyon blokları, metin artıkları).
2. `VerifyV1ToV2Invariants.s.sol` dosyasında da merge-artifact benzeri artıklar bulunuyor.
3. Yerel ortamda `forge` yok; bu nedenle sözleşme derleme ve testleri burada tekrar doğrulanamadı.

---

## 1) İnceleme Kapsamı

Bu analiz aşağıdaki bileşenleri kapsar:
- v1 token: `src/aoxcore-v1/AOXC.sol`
- v2 core: `src/aoxcore-v2/core/AoxcCore.sol`
- rehearsal script: `script/RehearseV1ToV2.s.sol`
- post-check script: `script/VerifyV1ToV2Invariants.s.sol`
- parity testi: `test/02_Integration/V1V2Parity.t.sol`
- runbook: `docs/MIGRATION_REHEARSAL_RUNBOOK.md`

---

## 2) Pozitif Bulgular

1. Runbook tarafında süreç mantığı doğru kurgulanmış: slot check → rehearsal deploy → invariant verify → DAO sign-off.
2. Parity test dosyası; blacklist, max transfer, daily limit, pause semantics ve mint policy gibi kritik başlıkları kapsıyor.
3. Rehearse scripti v1 ve v2 proxy bootstrap akışını (test/rehearsal amaçlı) net kuruyor.

Bu üç nokta, süreç tasarımının doğru yönde olduğunu gösteriyor.

---

## 3) Kritik Blokajlar (NO-GO Sebepleri)

### 3.1 `AoxcCore.sol` içinde bozulmuş kod belirtileri

Aşağıdaki belirtiler doğrudan dosya bütünlüğü sorununa işaret eder:
- Aynı constant’ların ikinci kez tanımlanması (`YEAR_SECONDS`, `HARD_CAP_INFLATION_BPS`, `V1_PARITY_ANCHOR_SUPPLY`).
- `setCriticalAddress` ve `setNeuralProtectMode` fonksiyonlarının duplicate/yarım bloklar halinde görünmesi.
- Kaynak dosya içine düz metin olarak `develop` ve `codex/hello` artıkları girmiş olması.

Bu seviyedeki bozulma, üretim deploy öncesi “mutlak düzeltme” gerektirir.

### 3.2 `VerifyV1ToV2Invariants.s.sol` dosyasında artifact kalıntıları

Dosyada:
- Duplicate import,
- düz metin `develop` / `codex/hello` artıkları,
- tekrar eden kontrol blokları
bulunuyor.

Bu script, yükseltme sonrası güvence için kritik olduğu için temiz ve deterministic olmalıdır.

### 3.3 Bu ortamda `forge` yok

`forge build` komutu çalıştırıldığında `command not found: forge` döndü. Bu nedenle burada lokal derleme/test tekrar doğrulaması tamamlanamadı.

---

## 4) “v2 core uygun mu?” sorusunun net cevabı

**Mimari hedef olarak uygun; mevcut dosya durumu ile deploy’a uygun değil.**

Yani konsept olarak v2 core (mint policy parity, role model, transfer guardlar, blacklist/pause yapısı) hedefe yakın görünse de, repo içindeki mevcut kaynak dosya bütünlüğü nedeniyle “hatasız yükseltme” garantisi verilemez.

---

## 5) “Hatasız yükseltme olur mu?” sorusunun net cevabı

Mevcut durumda: **Hayır, garanti edemem**.

Hatasız yükseltme için minimum koşullar:
1. `AoxcCore.sol` ve `VerifyV1ToV2Invariants.s.sol` dosyalarının merge-artifact temizliği.
2. `forge build` yeşil.
3. `forge test` (özellikle `V1V2Parity`) yeşil.
4. `python script/check_storage_slots.py` yeşil.
5. Rehearsal + post-verify scriptlerinin testnet/fork üzerinde başarılı çalışması.

---

## 6) Önerdiğim Uygulanabilir Plan (Hızlı)

### Faz-A (Bugün)
1. `AoxcCore.sol` syntax/merge temizliği.
2. `VerifyV1ToV2Invariants.s.sol` temizliği.
3. Lokal/CI’de Foundry toolchain sabitleme (`foundryup` + versiyon pin).

### Faz-B (Yarın)
1. `forge build` + `forge test` + `V1V2Parity` raporu.
2. Rehearsal script ile fork/testnet prova.
3. Invariant script çıktılarının DAO sign-off paketine eklenmesi.

### Faz-C (RC kararı)
1. GO/NO-GO toplantısı: teknik + güvenlik + governance.
2. Production’da kontrollü rollout (izleme + rollback planı).

---

## 7) Son Cümle (Operasyonel Karar)

Evet, bu turda deploy readiness’i tekrar inceledim. **Şu an production yükseltme için NO-GO** öneriyorum. Önce kaynak bütünlüğü (özellikle v2 core ve invariant script), sonra build/test/rehearsal zinciri tamamlanmalı.
