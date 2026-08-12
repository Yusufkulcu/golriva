-- ============================================================
-- GOLRIVA FAZ 2.23 — ARKADAŞ LİGİ YÖNETİM PANELİ İZİNLERİ
--   Panel (service_role anahtarı) tabloları RLS'siz okur; ama fonksiyon
--   çağrıları için EXECUTE izni gerekir — faz2_19 bu fonksiyonları
--   istemcilere kapatırken PUBLIC iznini de düşürmüştü.
--   Panele açılanlar:
--     * alig_iptal(uuid)      — açık ligi iptal + herkese iade
--     * alig_zaman_kontrol()  — süre/doluluk süpürmesini elle çalıştır
--     * alig_ad_uygun(text)   — küfür filtresi deneme kutusu
--   (kufur_listesi tablosu RLS'li ve politikasız — panel service_role
--    ile doğrudan okur/yazar, istemciler göremez.)
-- faz2_19 üzerine, idempotent.
-- ============================================================

grant execute on function alig_iptal(uuid) to service_role;
grant execute on function alig_zaman_kontrol() to service_role;
grant execute on function alig_ad_uygun(text) to service_role;

notify pgrst, 'reload schema';
