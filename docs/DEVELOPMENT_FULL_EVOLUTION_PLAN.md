# AOXCORE Full Gelişim Planı (Develop Track)

Bu planın amacı: v1'den v2'ye geçişte **storage güvenliğini korumak**, DAO + AI entegrasyonunu denetlenebilir hale getirmek ve kurumsal kaliteye ulaşmak.

## 1. İlk 2 Hafta — Güvenlik Stabilizasyonu
- [x] Kritik slot çakışmaları düzeltildi (Nexus/Gateway/Cpex Main).
- [x] `AoxcCore.initializeV2` için sıfır adres / sıfır hash guard eklendi.
- [x] Slot uniqueness scripti eklendi.
- [ ] Tüm upgradeable modüller için slot doğrulamasını teste bağla.
- [ ] v1->v2 migration smoke testi ekle (proxy üzerinden).

## 2. 2–4 Hafta — Governance Doğruluk
- Quorum hesabını BPS yerine snapshot total supply tabanlı normalize et.
- Proposal state geçişleri için edge-case testleri ekle:
  - veto sonrası execute engeli,
  - deadline sonrası queue/execute kuralları,
  - replay/nonced voting kontrolü.

## 3. 4–6 Hafta — AI Yetki Sınırlandırma
- AI aksiyonlarını 3 seviyeye ayır:
  1. advisory (sadece sinyal),
  2. guarded (çoklu imza + timelock),
  3. emergency (sınırlı kapsam + otomatik rollback).
- `NeuralPacket` versiyonlama ve domain ayrımı (prod/stage) ekle.
- Risk policy registry (on-chain) oluştur; backend sadece policy okuyucu olsun.

## 4. 6+ Hafta — Operasyonel Kurumsallaşma
- CI release gate: slot-check + forge test + lint + static analyzer.
- Incident response runbook (on-chain freeze / rollback / postmortem).
- Rollout stratejisi: canary deployment -> guardian gözlem -> full activation.

## 5. Ölçülebilir KPI
- Critical security finding: 0
- Upgrade rehearsal başarısı: %100
- Governance regression test pass rate: %100
- AI-triggered action audit coverage: %100 event + trace
