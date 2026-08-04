-- ============================================================
-- GOLRIVA FAZ 2.11 — TEK CİHAZ OTURUMU (anti-hile)
-- Bir hesap aynı anda tek cihazda aktif olabilir. Yeni bir cihazdan
-- giriş yapıldığında (ya da uygulama açıldığında) o cihaz "aktif" olur;
-- diğer cihaz kendini kontrol edip otomatik çıkış yapar.
-- Supabase SQL editöründe çalıştır.
-- ============================================================

create table if not exists aktif_oturum (
  user_id    uuid primary key references profiller(id) on delete cascade,
  cihaz_id   text not null,
  guncel_at  timestamptz not null default now()
);
alter table aktif_oturum enable row level security;
-- istemci doğrudan OKUYAMAZ/yazamaz; yalnız aşağıdaki RPC'lerle çalışır.

-- Bu cihazı hesabın AKTİF cihazı yap (giriş + uygulama açılışında çağrılır).
create or replace function oturum_sahiplen(cihaz_p text)
  returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or cihaz_p is null then return; end if;
  insert into aktif_oturum (user_id, cihaz_id, guncel_at)
    values (auth.uid(), left(cihaz_p, 64), now())
    on conflict (user_id) do update
      set cihaz_id = excluded.cihaz_id, guncel_at = now();
end $$;
grant execute on function oturum_sahiplen(text) to anon, authenticated;

-- Bu cihaz hâlâ aktif mi? false → başka cihaz devraldı, çıkış yapılmalı.
-- Kayıt yoksa true döner (yanlışlıkla çıkış yaptırmamak için).
create or replace function oturum_benim_mi(cihaz_p text)
  returns boolean language plpgsql security definer set search_path = public stable as $$
declare aktif text;
begin
  if auth.uid() is null then return true; end if;
  select cihaz_id into aktif from aktif_oturum where user_id = auth.uid();
  if aktif is null then return true; end if;
  return aktif = left(cihaz_p, 64);
end $$;
grant execute on function oturum_benim_mi(text) to anon, authenticated;

notify pgrst, 'reload schema';
