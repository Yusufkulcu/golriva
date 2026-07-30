-- ============================================================================
-- GOLRIVA — Lig Sistemi Eklentisi v1 (supabase_sema_v2.sql + admin_ek.sql üzerine)
-- İLKE: Elo EŞLEŞTİRİR, Lig ÖDÜLLENDİRİR. Lig asla eşleştirme kriteri değildir.
-- Simülasyonla doğrulanan merdiven: ilk terfi ~9 maç, ortalama oyuncu ~125 maçta
-- Süper Lig, Avrupa+ yalnız %55+ kazananlarda kalıcı. (tasarim/lig_sistemi_v1.md)
-- ============================================================================

-- ---------- 1. LİG KONFİGÜRASYONU (ayar düğmeleri DB'de) ----------
create table if not exists ligler (
  kod         text primary key,
  ad          text not null,
  sira        integer not null unique,          -- 1=Amatör ... 7=Şampiyonlar Ligi
  terfi_esigi integer not null,                 -- bu puana ulaşan bir üst lige çıkar
  g_bo1       integer not null,                 -- Bo1 galibiyet puanı
  k_bo1       integer not null,                 -- Bo1 mağlubiyet puanı (<=0)
  g_bo3       integer not null,
  k_bo3       integer not null
);
insert into ligler (kod, ad, sira, terfi_esigi, g_bo1, k_bo1, g_bo3, k_bo3) values
  ('amator','Amatör Küme',      1,  15, 3,  0, 5,  0),
  ('lig3',  '3. Lig',           2,  18, 3, -1, 5, -2),
  ('lig2',  '2. Lig',           3,  24, 3, -1, 5, -2),
  ('lig1',  '1. Lig',           4,  30, 3, -2, 5, -3),
  ('super', 'Süper Lig',        5,  36, 3, -3, 5, -5),
  ('avrupa','Avrupa Ligi',      6,  40, 2, -3, 3, -5),
  ('sampiyonlar','Şampiyonlar Ligi', 7, 1000000, 2, -3, 3, -5)
on conflict (kod) do update set terfi_esigi=excluded.terfi_esigi,
  g_bo1=excluded.g_bo1, k_bo1=excluded.k_bo1, g_bo3=excluded.g_bo3, k_bo3=excluded.k_bo3;

-- ---------- 2. OYUNCU LİG DURUMU + SEZONLAR ----------
alter table profiller add column if not exists lig_kod  text not null default 'amator' references ligler(kod);
alter table profiller add column if not exists lig_puan integer not null default 0;

create table if not exists sezonlar (
  id         integer generated always as identity primary key,
  ad         text not null,
  baslangic  timestamptz not null default now(),
  bitis      timestamptz,
  aktif      boolean not null default true
);
insert into sezonlar (ad) select 'Sezon 1'
  where not exists (select 1 from sezonlar);

create table if not exists lig_gecmisi (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references profiller(id) on delete cascade,
  olay       text not null check (olay in ('terfi','dusme','sezon_sifirlama')),
  eski_lig   text not null,
  yeni_lig   text not null,
  created_at timestamptz not null default now()
);
alter table lig_gecmisi enable row level security;
create policy p_liggec_oku on lig_gecmisi for select using (user_id = auth.uid());
alter table ligler enable row level security;
create policy p_ligler_oku on ligler for select using (true);
alter table sezonlar enable row level security;
create policy p_sezon_oku on sezonlar for select using (true);

-- ---------- 3. PUAN İŞLEME (seri_kapat çağırır; berabere = puan yok) ----------
create or replace function lig_puan_isle(u uuid, kazandi boolean, md text) returns void
language plpgsql security definer set search_path = public as $$
declare p profiller; l ligler; delta integer; yeni_puan integer;
        alt ligler; ust ligler;
begin
  select * into p from profiller where id = u for update;
  select * into l from ligler where kod = p.lig_kod;
  if md = 'bo3' then delta := case when kazandi then l.g_bo3 else l.k_bo3 end;
  else               delta := case when kazandi then l.g_bo1 else l.k_bo1 end;
  end if;
  yeni_puan := p.lig_puan + delta;

  if yeni_puan >= l.terfi_esigi then
    select * into ust from ligler where sira = l.sira + 1;
    if found then
      update profiller set lig_kod = ust.kod, lig_puan = 0 where id = u;
      insert into lig_gecmisi (user_id, olay, eski_lig, yeni_lig) values (u,'terfi',l.kod,ust.kod);
    else
      update profiller set lig_puan = yeni_puan where id = u;  -- zirvede birikir (sezon şeref sıralaması)
    end if;
  elsif yeni_puan < 0 then
    select * into alt from ligler where sira = l.sira - 1;
    if found then
      update profiller set lig_kod = alt.kod, lig_puan = greatest(0, alt.terfi_esigi - 6) where id = u;
      insert into lig_gecmisi (user_id, olay, eski_lig, yeni_lig) values (u,'dusme',l.kod,alt.kod);
    else
      update profiller set lig_puan = 0 where id = u;          -- Amatör'den düşülmez
    end if;
  else
    update profiller set lig_puan = yeni_puan where id = u;
  end if;
end $$;

-- ---------- 4. seri_kapat ENTEGRASYONU (v2 fonksiyonunun lig'li sürümü) ----------
create or replace function seri_kapat(sid uuid, kazanan_p uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s seriler; m masalar; g integer; net integer; bnet integer; rake integer;
        e1 integer; e2 integer; beklenen numeric; k integer := 32; kaybeden uuid;
begin
  select * into s from seriler where id = sid for update;
  select * into m from masalar where kod = s.masa_kod;
  if not s.dostluk then
    g := masa_giris(m, s.mod);
    if s.mod = 'bo3' then net := m.kazanan_net_bo3; bnet := m.berabere_net_bo3;
    else net := m.kazanan_net; bnet := m.berabere_net; end if;
    if kazanan_p is null then
      insert into defter (user_id, tip, miktar, seri_id) values
        (s.p1, 'berabere_iade', g + bnet, sid),
        (s.p2, 'berabere_iade', g + bnet, sid);
      rake := -2 * bnet;
    else
      if kazanan_p not in (s.p1, s.p2) then raise exception 'kazanan seride değil'; end if;
      insert into defter (user_id, tip, miktar, seri_id)
        values (kazanan_p, 'seri_odul', g + net, sid);
      rake := 2 * g - (g + net);
    end if;
    insert into defter (user_id, tip, miktar, seri_id, aciklama)
      values ('00000000-0000-0000-0000-000000000001', 'rake', rake, sid, s.masa_kod || '/' || s.mod);
    if kazanan_p is not null then
      kaybeden := case when kazanan_p = s.p1 then s.p2 else s.p1 end;
      -- Elo (beceri terazisi)
      select elo into e1 from profiller where id = kazanan_p;
      select elo into e2 from profiller where id = kaybeden;
      beklenen := 1.0 / (1.0 + power(10.0, (e2 - e1) / 400.0));
      update profiller set elo = elo + round(k * (1 - beklenen)) where id = kazanan_p;
      update profiller set elo = greatest(100, elo - round(k * (1 - beklenen))) where id = kaybeden;
      -- Lig (ilerleme merdiveni) — berabere seride puan işlenmez
      perform lig_puan_isle(kazanan_p, true,  s.mod);
      perform lig_puan_isle(kaybeden,  false, s.mod);
    end if;
  end if;
  update seriler set durum = 'bitti', kazanan = kazanan_p, finished_at = now()
    where id = sid;
end $$;

-- ---------- 5. SEZON SIFIRLAMA (admin/cron; yumuşak iniş) ----------
-- Herkes BİR alt ligin başına iner (Amatör ve 3. Lig oyuncuları Amatör başı).
create or replace function sezon_sifirla(yeni_ad text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update sezonlar set aktif = false, bitis = now() where aktif;
  insert into sezonlar (ad) values (yeni_ad);
  insert into lig_gecmisi (user_id, olay, eski_lig, yeni_lig)
    select p.id, 'sezon_sifirlama', p.lig_kod, coalesce(alt.kod, 'amator')
    from profiller p
    join ligler l on l.kod = p.lig_kod
    left join ligler alt on alt.sira = l.sira - 1
    where p.lig_kod <> 'amator';
  update profiller p set
    lig_kod  = coalesce((select alt.kod from ligler l join ligler alt on alt.sira = l.sira - 1
                         where l.kod = p.lig_kod), 'amator'),
    lig_puan = 0;
end $$;

-- ---------- 6. ADMIN GÖRÜNÜMÜ ----------
create or replace view v_lig_dagilim as
select l.ad, l.sira, count(p.id) as oyuncu
from ligler l left join profiller p on p.lig_kod = l.kod
group by l.ad, l.sira order by l.sira;
