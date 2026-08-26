-- ============================================================
-- GOLRIVA FAZ 2.27 — RIVA PAKET YAPISI 4'LÜYE GEÇİŞ
--   Kullanıcı kararı: 500 / 1000 / 2500 / 5000 (App Store'da bu
--   kimliklerle oluşturuldu; Play Console'da da AYNI kimlikler
--   açılmalı: riva_1000 + riva_2500, riva_1500 kullanımdan kalkar).
--   Görünüm fiyatları (fiyat_metni) YAKLAŞIKTIR — canlı fiyat her
--   zaman mağazadan gelir; admin panel → Market'ten düzeltilebilir.
-- faz2_7_market üzerine, idempotent.
-- ============================================================

-- eski orta paket satıştan kalkar (geçmiş satın almalar defterde kalır)
update urunler set aktif = false where kod = 'riva_1500';

insert into urunler (kod, ad, riva, sira, aktif, fiyat_metni) values
  ('riva_500',  'Başlangıç',  500, 1, true, '₺49,99'),
  ('riva_1000', 'Popüler',   1000, 2, true, '₺89,99'),
  ('riva_2500', 'Avantaj',   2500, 3, true, '₺199,99'),
  ('riva_5000', 'Kral',      5000, 4, true, '₺349,99')
on conflict (kod) do update set
  ad = excluded.ad, riva = excluded.riva, sira = excluded.sira,
  aktif = true;
-- NOT: mevcut kayıtların fiyat_metni'sine DOKUNMAZ (admin ne girdiyse
-- o kalır); yalnız yeni eklenenler yukarıdaki yaklaşık değerle başlar.

notify pgrst, 'reload schema';
