-- =============================================================
-- GOLRIVA FAZ 2.3b — sunucu saati (31 Tem 2026)
-- Geri sayim iki cihazda SUNUCU zamanina gore ayni anda baslasin diye:
-- baslangic ani = ikinci 'hazir' sinyalinin sunucu_ts'i + 4 sn.
-- Istemciler bu fonksiyonla sunucu "simdi"sini ogrenip kalan sureyi
-- hesaplar — yerel saat farklari ve yoklama gecikmesi elenir.
-- =============================================================
create or replace function sunucu_saati() returns timestamptz
language sql stable as $$ select now() $$;
grant execute on function sunucu_saati() to authenticated, anon;
