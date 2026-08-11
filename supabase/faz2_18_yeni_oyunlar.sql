-- ============================================================
-- FAZ 2.18 — 5 YENİ OYUN: KİM BU? · DAHA MI YÜKSEK? · SIRALA
-- BAKALIM · ORTAK KULÜP AVI · ŞL GECESİ
-- Supabase SQL Editor'de bir kez çalıştır (idempotent).
--
-- random_havuz = FALSE başlar: ranked ruletine HENÜZ girmezler —
-- eski sürümdeki istemciler bu kodları tanımaz ("Bilinmeyen oyun").
-- Güncelleme kullanıcılara yayıldıktan sonra şunu çalıştır
-- (bonservis_21 + veto_drafti ile birlikte 7'sini birden açabilirsin):
--   update oyunlar set random_havuz = true
--    where kod in ('bonservis_21','veto_drafti','kim_bu',
--                  'daha_mi_yuksek','sirala_bakalim','ortak_kulup',
--                  'sl_gecesi');
--
-- Dostluk / hedefli davet yolu random_havuz'a bakmaz: güncel
-- istemciler yeni oyunları HEMEN davetle oynayabilir.
-- ============================================================

insert into oyunlar (kod, ad, random_havuz) values
  ('kim_bu',          'Kim Bu?',          false),
  ('daha_mi_yuksek',  'Daha mı Yüksek?',  false),
  ('sirala_bakalim',  'Sırala Bakalım',   false),
  ('ortak_kulup',     'Ortak Kulüp Avı',  false),
  ('sl_gecesi',       'ŞL Gecesi',        false)
on conflict (kod) do nothing;
