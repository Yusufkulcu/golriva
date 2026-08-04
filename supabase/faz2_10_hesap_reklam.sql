-- ============================================================
-- GOLRIVA FAZ 2.10 — HESAP SİLME + MAÇ SONU REKLAMI (günlük limit)
-- Supabase SQL editöründe çalıştır.
-- ============================================================

-- ── HESABIMI SİL (kullanıcı kendi hesabını siler) ────────────
-- Engeller: seriler.p1/p2, hamleler, defter, davetler (cascade DEĞİL) —
-- FK-güvenli sırayla temizlenir, en son auth.users silinince kalan her şey
-- (profil, cüzdan, arkadaşlık, satın alma, cihaz jetonu…) cascade ile gider.
create or replace function hesabimi_sil() returns void
  language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'oturum yok'; end if;
  -- davetler: seri_id (cascade değil) engelini kaldır
  delete from davetler
    where kurucu = u
       or seri_id in (select id from seriler where p1 = u or p2 = u);
  delete from hamleler where user_id = u;
  delete from seriler  where p1 = u or p2 = u;   -- cascade: maclar → hamleler
  delete from defter   where user_id = u;
  delete from profiller where id = u;            -- cascade: cüzdan/kuyruk/arkadaş/
                                                 -- reklam/satın alma/lig/itiraz…
  delete from auth.users where id = u;           -- cascade: cihaz_tokenleri; girişi kapatır
end $$;
grant execute on function hesabimi_sil() to authenticated, anon;

-- ── AYARLAR (admin panelden yönetilir) ───────────────────────
create table if not exists ayarlar (
  anahtar   text primary key,
  deger     text,
  guncel_at timestamptz not null default now()
);
alter table ayarlar enable row level security;  -- istemci OKUYAMAZ; RPC/panel okur
insert into ayarlar (anahtar, deger) values ('gunluk_reklam', '4')
  on conflict (anahtar) do nothing;             -- varsayılan: kullanıcı başına günde 4 maç-sonu reklamı

-- ── MAÇ SONU REKLAM GÖSTERİMLERİ ─────────────────────────────
create table if not exists reklam_gosterimleri (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references profiller(id) on delete cascade,
  tur        text not null default 'mac_sonu',
  created_at timestamptz not null default now()
);
create index if not exists reklam_gost_kullanici_gun
  on reklam_gosterimleri (user_id, created_at);
alter table reklam_gosterimleri enable row level security;  -- panel okur

-- Günlük reklam limiti (int). Ayar yoksa/geçersizse 0 (reklam kapalı).
create or replace function reklam_ayari() returns integer
  language sql security definer set search_path = public stable as $$
  select coalesce(nullif((select deger from ayarlar where anahtar='gunluk_reklam'),'')::int, 0);
$$;
grant execute on function reklam_ayari() to anon, authenticated;

-- Bu kullanıcının BUGÜN kalan maç-sonu reklam hakkı (0 → gösterme).
create or replace function reklam_gosterim_hakki() returns integer
  language plpgsql security definer set search_path = public stable as $$
declare u uuid := auth.uid(); limit_ int; bugun int;
begin
  if u is null then return 0; end if;
  limit_ := reklam_ayari();
  if limit_ <= 0 then return 0; end if;
  select count(*) into bugun from reklam_gosterimleri
    where user_id = u and created_at >= date_trunc('day', now());
  return greatest(limit_ - bugun, 0);
end $$;
grant execute on function reklam_gosterim_hakki() to authenticated;

-- Bir maç-sonu reklamı gösterildi → kaydet (limit aşımını sunucuda da doğrula).
create or replace function reklam_gosterildi() returns void
  language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); limit_ int; bugun int;
begin
  if u is null then return; end if;
  limit_ := reklam_ayari();
  select count(*) into bugun from reklam_gosterimleri
    where user_id = u and created_at >= date_trunc('day', now());
  if bugun >= limit_ then return; end if;   -- tavan doldu → sessizce yut
  insert into reklam_gosterimleri (user_id, tur) values (u, 'mac_sonu');
end $$;
grant execute on function reklam_gosterildi() to authenticated;

notify pgrst, 'reload schema';
