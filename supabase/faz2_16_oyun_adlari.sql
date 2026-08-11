-- ============================================================
-- GOLRIVA FAZ 2.16 — OYUN ADI GÜNCELLEMELERİ (kullanıcı isteği)
-- Panel ve sunucu tarafındaki görünen adlar; idempotent.
-- ============================================================
update oyunlar set ad = 'En Kısa Kadroyu Kur'      where kod = 'en_kisa_kadro';
update oyunlar set ad = 'En Genç Kadroyu Kur'      where kod = 'en_genc_kadro';
update oyunlar set ad = 'Milli Takım Gol Kralları' where kod = 'milli_gol_krallari';
