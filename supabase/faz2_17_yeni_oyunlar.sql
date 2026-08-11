-- ============================================================
-- FAZ 2.17 — YENİ OYUNLAR: BONSERVİS 21'İ + VETO DRAFTI
-- Supabase SQL Editor'de bir kez çalıştır (idempotent).
--
-- İki yeni oyun kodu eklenir. random_havuz = FALSE başlar:
-- ranked ruletine HENÜZ girmezler — eski sürümdeki istemciler bu
-- kodları tanımadığı için maçta "Bilinmeyen oyun" görürdü.
-- Güncelleme kullanıcılara yayıldıktan sonra (birkaç gün) şunu çalıştır:
--   update oyunlar set random_havuz = true
--    where kod in ('bonservis_21', 'veto_drafti');
--
-- Dostluk daveti / hedefli davet yolu random_havuz'a bakmaz:
-- güncel istemciler yeni oyunları HEMEN davetle oynayabilir.
-- ============================================================

insert into oyunlar (kod, ad, random_havuz) values
  ('bonservis_21', 'Bonservis 21''i', false),
  ('veto_drafti',  'Veto Draftı',    false)
on conflict (kod) do nothing;
