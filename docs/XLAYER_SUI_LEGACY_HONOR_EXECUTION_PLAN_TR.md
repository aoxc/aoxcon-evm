# AOXCORE Mimari Yol Haritası (Birlikte Güçlüyüz)

Bu belge; **vefayı, teknik kaliteyi ve büyüme disiplinini** aynı zeminde buluşturur.
Hedefimiz: v1 mirasını onurlandırırken, AOXC-XAS ile Sui + XLayer + gelecekte Cardano uyumlu egemen bir altyapıyı zarif şekilde inşa etmek.

---

## 1) Vefa Katmanı — v1 Sahipleri Sistemde Onur Üyesi

### Neden?
İlk yol arkadaşlarını dışarıda bırakan mimari uzun ömürlü olmaz. v1 AOXC sahipleri, ekosistemin kurucu hafızasıdır.

### Ne yapıyoruz?
- v1 tokenları silinmiyor.
- XLayer snapshot doğrulamasıyla **Onur Üyeliği (Honor XP)** statüsü oluşturuluyor.
- Sui tarafında bu statü, DAO kararlarında **muhafaza edilen bir itibar çarpanı** olarak kullanılıyor.

### Teknik karşılığı
- `reputation.move`: `HonorXP` + `vote_power(base + multiplier)` mantığı.
- `treasury.move`: kurucu hakları için **Founder Vault** ödül indeksleme ve claim akışı.

---

## 2) AOXC-XAS — Evrensel Anahtar

AOXC-XAS, “v1’in yerine geçip geçmişi silen” bir tasarım değil; tam tersine, vefayı koruyup çok-zincir ekonomiyi ileri taşıyan yeni işlem anahtarıdır.

### Tasarım prensipleri
1. **Atomic mint/burn:** tekil mesaj kimliği ile idempotent geçiş.
2. **Storage-agnostic:** ağır veri Walrus’ta; zincirde hash + pointer.
3. **Expansion-ready:** Sui ve XLayer için ortak veri şeması; Ada için adapter slot.

---

## 3) Hassas Onay — Çift Kontrollü Doğrulama

“Güvensizlik” dili yerine **tam doğruluk** dili:
- İmza doğrulaması,
- ZK/kanıt kökü doğrulaması,
- Finality buffer sonrası tüketim,
- nonce + replay koruması.

### Teknik karşılığı
- `neural_bridge.move`:
  - `finality_buffer_ms`
  - `approved_signers`
  - `approved_zk_proofs`
  - `verify_and_consume` içinde finality + replay + çift onay kapısı.

---

## 4) Otonom Denge — Huzur Mekanizması

Sistem adaleti, manuel operasyon yükü olmadan sürdürülebilir olmalı.

### Teknik karşılığı
- `auto_rebalancer.move`:
  - Founder / XAS / Reserve paylarının BPS tabanlı politikası,
  - politika toplamı zorunlu 10000 bps,
  - gelirlerin deterministik bölünmesi.

Bu sayede v1 dostlarının hakkı ve yeni AOXC-XAS kullanım ekonomisi aynı anda korunur.

---

## 5) Cardano Genişleme Kapısı (Şimdiden Hazır)

Cardano entegrasyonu bugünden çekirdek kodu kırmadan hazırlanır:
- zincire özel farklar adapter/verifier katmanında izole edilir,
- çekirdek mantık zincir bağımsız kalır,
- yarın yeni doğrulayıcı eklenerek genişleme yapılır.

---

## 6) 90 Günlük Uygulama Planı

### Faz-1 (0-30 gün)
- v1 snapshot + Honor XP dağıtım kuralları dondurulur.
- Founder Vault hak sahipliği ve claim testi tamamlanır.
- Bridge finality + replay + dual-gate senaryoları test edilir.

### Faz-2 (31-60 gün)
- AOXC-XAS mint/burn mesaj şeması versiyonlanır.
- Walrus CID + hash mühür akışı netleştirilir.
- canary ortamında uçtan uca senaryo koşulur.

### Faz-3 (61-90 gün)
- Governance onaylı kademeli aktivasyon.
- Cardano verifier adapter slotu “plug-in ready” hale getirilir.
- operasyon runbook ve incident playbook finalize edilir.

---

## 7) Mimari Manifesto (Kısa)

- **Vefa:** v1 silinmez, saygın statüye yükselir.
- **Denge:** yeni ekonomi AOXC-XAS ile büyür.
- **Doğruluk:** çift kontrollü onay ve finality disiplini uygulanır.
- **Genişleme:** Sui + XLayer bugün, Cardano yarın; çekirdek yarın da sade kalır.

> Birlikte güçlüyüz: geçmişi onurlandıran, bugünü güvenceleyen, geleceğe açık bir egemen altyapı.
