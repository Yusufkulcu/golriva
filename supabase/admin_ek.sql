-- ============================================================================
-- GOLRIVA — Admin Eklentisi v1 (supabase_sema_v2.sql ÜZERİNE çalışır)
-- Panel service_role anahtarıyla bağlanır (RLS'yi aşar) — panel YALNIZ yerelde
-- çalıştırılır, anahtar asla istemciye/siteye gömülmez.
-- ============================================================================

-- ---------- 1. YASAKLAMA ----------
alter table profiller add column if not exists yasakli boolean not null default false;
alter table profiller add column if not exists yasak_nedeni text;

-- Yasaklı oyuncu kuyruğa giremez (kuyruga_gir'e ek kontrol)
create or replace function kuyruga_gir(md text, masa text) returns void
language plpgsql security definer set search_path = public as $$
declare m masalar; b integer; e integer; gerekli integer; yasak boolean;
begin
  select yasakli into yasak from profiller where id = auth.uid();
  if yasak then raise exception 'hesap yasaklı'; end if;
  if md not in ('bo1','bo3') then raise exception 'geçersiz mod'; end if;
  select * into m from masalar where kod = masa and aktif;
  if not found then raise exception 'masa yok'; end if;
  gerekli := masa_giris(m, md);
  select bakiye into b from cuzdanlar where user_id = auth.uid() for update;
  if b < gerekli then raise exception 'yetersiz bakiye'; end if;
  if b < m.min_bakiye_kilit then raise exception 'masa kilitli'; end if;
  select elo into e from profiller where id = auth.uid();
  insert into eslestirme_kuyrugu (user_id, mod, masa_kod, elo)
    values (auth.uid(), md, masa, e)
  on conflict (user_id) do update
    set mod = excluded.mod, masa_kod = excluded.masa_kod, created_at = now();
end $$;

-- ---------- 2. VERİ İTİRAZ KUYRUĞU ("her itirazı ciddiye al") ----------
create table if not exists veri_itirazlari (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references profiller(id) on delete cascade,
  oyuncu_adi  text not null,           -- hangi futbolcunun verisi
  mesaj       text not null,           -- itiraz metni
  durum       text not null default 'acik' check (durum in ('acik','inceleniyor','duzeltildi','red')),
  admin_notu  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table veri_itirazlari enable row level security;
create policy p_itiraz_oku on veri_itirazlari for select using (user_id = auth.uid());

create or replace function itiraz_gonder(oyuncu text, m text) returns bigint
language plpgsql security definer set search_path = public as $$
declare yeni_id bigint;
begin
  if char_length(m) < 10 then raise exception 'itiraz çok kısa'; end if;
  -- kullanıcı başına günde 5 itiraz
  if (select count(*) from veri_itirazlari
      where user_id = auth.uid() and created_at >= date_trunc('day', now())) >= 5 then
    raise exception 'günlük itiraz sınırı';
  end if;
  insert into veri_itirazlari (user_id, oyuncu_adi, mesaj)
    values (auth.uid(), oyuncu, m) returning id into yeni_id;
  return yeni_id;
end $$;

-- ---------- 3. METRİK GÖRÜNÜMLERİ (panelin Pano sekmesi) ----------
create or replace view v_ozet as
select
  (select count(*) from profiller)                                            as toplam_kullanici,
  (select count(*) from profiller where created_at >= date_trunc('day',now())) as bugun_yeni,
  (select count(*) from seriler where durum = 'oyunda')                        as aktif_seri,
  (select count(*) from seriler where created_at >= date_trunc('day',now()))   as bugun_seri,
  (select coalesce(sum(miktar),0) from defter where tip='rake')                as kasa_toplam,
  (select coalesce(sum(miktar),0) from defter
     where tip='rake' and created_at >= date_trunc('day',now()))               as kasa_bugun,
  (select count(*) from reklam_odulleri
     where created_at >= date_trunc('day',now()))                              as bugun_reklam,
  (select coalesce(sum(bakiye),0) from cuzdanlar)                              as dolasimdaki_riva,
  (select count(*) from veri_itirazlari where durum='acik')                    as acik_itiraz;

create or replace view v_gunluk as
select d::date as gun,
  (select count(*) from profiller p where p.created_at::date = d::date)        as yeni_kullanici,
  (select count(*) from seriler s  where s.created_at::date = d::date)         as seri,
  (select coalesce(sum(miktar),0) from defter x
     where x.tip='rake' and x.created_at::date = d::date)                      as rake,
  (select count(*) from reklam_odulleri r where r.created_at::date = d::date)  as reklam
from generate_series(current_date - interval '13 day', current_date, interval '1 day') d
order by gun desc;

-- ---------- 4. ADMIN İŞLEMLERİ (service_role çağırır) ----------
-- Bakiye düzeltmesi: defterden geçer, iz bırakır (elle UPDATE asla yapılmaz)
create or replace function admin_duzeltme(u uuid, m integer, neden text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if neden is null or char_length(neden) < 5 then raise exception 'neden zorunlu'; end if;
  insert into defter (user_id, tip, miktar, aciklama) values (u, 'duzeltme', m, 'ADMIN: ' || neden);
end $$;

create or replace function admin_yasak(u uuid, durum boolean, neden text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update profiller set yasakli = durum, yasak_nedeni = case when durum then neden else null end
    where id = u;
  if durum then delete from eslestirme_kuyrugu where user_id = u; end if;
end $$;
