-- ============================================================
-- GOLRIVA FAZ 2.9 — PUSH BİLDİRİMİ (Firebase Cloud Messaging)
-- Cihaz token deposu + gönderim geçmişi. Gönderimi Edge Function
-- (bildirim-gonder) yapar; bu dosya yalnız veri tabanı tarafıdır.
-- Supabase SQL editöründe çalıştır.
-- ============================================================

-- ── CİHAZ TOKENLERİ ──────────────────────────────────────────
-- Her cihazın FCM kayıt jetonu. Bir kullanıcının birden çok cihazı
-- olabilir; token BENZERSİZ (aynı cihaz farklı kullanıcıya geçerse
-- user_id güncellenir).
create table if not exists cihaz_tokenleri (
  token       text primary key,
  user_id     uuid references auth.users(id) on delete cascade,
  platform    text,                       -- android / ios / web
  guncel_at   timestamptz not null default now()
);
create index if not exists cihaz_token_kullanici on cihaz_tokenleri (user_id);

alter table cihaz_tokenleri enable row level security;
-- istemci OKUYAMAZ/silemez; yalnız RPC ile yazar, panel (service_role) okur.

-- ── BİLDİRİM GEÇMİŞİ ─────────────────────────────────────────
-- Panelden gönderilen her bildirim buraya loglanır (Edge Function yazar).
create table if not exists bildirim_gecmisi (
  id          bigint generated always as identity primary key,
  hedef       text not null,              -- 'tum' | 'kullanici'
  user_id     uuid,                       -- hedef kullanıcı (varsa)
  baslik      text not null,
  govde       text not null,
  ses         text,                       -- 'cinlama' | 'zil' | 'sessiz'
  gonderildi  int not null default 0,     -- başarıyla iletilen cihaz
  basarisiz   int not null default 0,     -- iletilemeyen cihaz
  created_at  timestamptz not null default now()
);
create index if not exists bildirim_zaman on bildirim_gecmisi (created_at desc);

alter table bildirim_gecmisi enable row level security;
-- istemci OKUYAMAZ; panel (service_role) okur, Edge Function (service_role) yazar.

-- ── TOKEN KAYDET (istemci çağırır) ───────────────────────────
-- Uygulama açılışta/girişte FCM jetonunu buraya yazar. auth.uid()
-- tabanlı — misafir (anon) oturumlar da kaydeder.
create or replace function cihaz_token_kaydet(token_p text, platform_p text)
  returns void language plpgsql security definer set search_path = public as $$
begin
  if token_p is null or length(trim(token_p)) < 10 then
    return; -- geçersiz jeton — sessizce yut
  end if;
  insert into cihaz_tokenleri (token, user_id, platform, guncel_at)
  values (trim(token_p), auth.uid(), left(platform_p, 12), now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        guncel_at = now();
end $$;
grant execute on function cihaz_token_kaydet(text, text) to anon, authenticated;

-- ── TOKEN SİL (çıkışta çağrılır) ─────────────────────────────
create or replace function cihaz_token_sil(token_p text)
  returns void language plpgsql security definer set search_path = public as $$
begin
  delete from cihaz_tokenleri where token = trim(token_p);
end $$;
grant execute on function cihaz_token_sil(text) to anon, authenticated;

notify pgrst, 'reload schema';
