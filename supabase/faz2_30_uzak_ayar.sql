-- ============================================================
-- GOLRIVA FAZ 2.30 — UZAK AYARLAR: ZORUNLU MİNİMUM SÜRÜM + AÇMA/KAPAMA
--   Kullanıcı kararı: OTA (Shorebird) yalnız küçük düzeltmeler için;
--   büyük değişimlerde eski istemciler mağazaya ZORLANIR, patlayan bir
--   özellik panelden anında KAPATILIR (yeni build beklenmez).
--   * uzak_ayarlar: herkese açık OKUNUR (gizli bilgi içermez), yalnız
--     panel (service_role) yazar. Mevcut 'ayarlar' tablosu (gunluk_reklam)
--     istemciye kapalı kalır — o admin/sunucu ayarıdır.
-- Anahtarlar (deger metin; istemci türünü kendi çözer):
--   min_surum_android / min_surum_ios : '1.0.10' — altı GÜNCELLEME ekranı
--   bakim_modu ('0'/'1') + bakim_mesaj  : tüm istemciler bakım ekranında
--   reklam_acik ('1')                    : ödüllü + geçiş reklamları
--   gecis_reklam_yuzde ('50')            : maç sonu geçiş reklamı ihtimali
--   magaza_acik ('1')                    : Riva paketleri satışı
--   arkadas_ligi_acik ('1')              : Arkadaş Ligi girişi
--   magaza_url_android / magaza_url_ios  : GÜNCELLE butonunun hedefi
-- İdempotent.
-- ============================================================

create table if not exists uzak_ayarlar (
  anahtar    text primary key,
  deger      text not null default '',
  aciklama   text,
  guncel_at  timestamptz not null default now()
);
alter table uzak_ayarlar enable row level security;
do $$ begin
  create policy p_uzak_ayar_oku on uzak_ayarlar for select
    to anon, authenticated using (true);
exception when duplicate_object then null; end $$;
-- yazma politikası YOK: yalnız service_role (panel) günceller

insert into uzak_ayarlar (anahtar, deger, aciklama) values
  ('min_surum_android', '1.0.0',  'Bu sürümün altındaki Android istemciler mağazaya yönlendirilir'),
  ('min_surum_ios',     '1.0.0',  'Bu sürümün altındaki iOS istemciler mağazaya yönlendirilir'),
  ('bakim_modu',        '0',      '1 = tüm istemciler bakım ekranında bekler'),
  ('bakim_mesaj',       'Kısa bir bakım yapıyoruz, birkaç dakika içinde döneceğiz.', 'Bakım ekranı metni'),
  ('reklam_acik',       '1',      '0 = ödüllü ve geçiş reklamları tamamen kapalı'),
  ('gecis_reklam_yuzde','50',     'Maç sonunda (ödüllü izlenmediyse) geçiş reklamı ihtimali, 0-100'),
  ('magaza_acik',       '1',      '0 = Riva paketleri satışı geçici kapalı'),
  ('arkadas_ligi_acik', '1',      '0 = Arkadaş Ligi girişi geçici kapalı'),
  ('magaza_url_android','https://play.google.com/store/apps/details?id=com.golriva', 'GÜNCELLE butonu hedefi (Android)'),
  ('magaza_url_ios',    'https://apps.apple.com/app/golriva/id0000000000', 'GÜNCELLE butonu hedefi (iOS) — App Store kimliğiyle düzelt')
on conflict (anahtar) do nothing;

-- guncel_at otomatik
create or replace function uzak_ayar_ts() returns trigger
language plpgsql as $$
begin new.guncel_at := now(); return new; end $$;
drop trigger if exists trg_uzak_ayar_ts on uzak_ayarlar;
create trigger trg_uzak_ayar_ts before update on uzak_ayarlar
  for each row execute function uzak_ayar_ts();

notify pgrst, 'reload schema';
