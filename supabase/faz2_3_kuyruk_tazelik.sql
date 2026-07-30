-- =============================================================
-- GOLRIVA FAZ 2.3a — kuyruk tazeligi (31 Tem 2026)
-- SORUN: kuyruktan duzgun cikmadan ayrilan istemcinin kaydi bayat
-- kaliyor ve eslestirici hayalet kayitla seri aciyordu.
-- COZUM: nabiz (son_gorulme) — eslesme SADECE son 12 sn icinde
-- aktif yoklama yapan (yani gercekten bekleme ekraninda olan)
-- oyuncularla kurulur. 2 dk'dan eski kayitlar otomatik silinir.
-- faz2_2_ek.sql SONRASINDA calistir.
-- =============================================================

alter table eslestirme_kuyrugu
  add column if not exists son_gorulme timestamptz not null default now();

-- kuyruga_gir: tekrar giriste nabiz da tazelenir
create or replace function kuyruga_gir(md text, masa text) returns void
language plpgsql security definer set search_path = public as $$
declare m masalar; b integer; e integer; gerekli integer;
begin
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
    set mod = excluded.mod, masa_kod = excluded.masa_kod,
        created_at = now(), son_gorulme = now();
end $$;

-- eslesme_dene: (1) kendi nabzimi tazele, (2) bayatlari temizle,
-- (3) SADECE taze (son 12 sn) rakiple eslen.
create or replace function eslesme_dene() returns uuid
language plpgsql security definer set search_path = public as $$
declare ben eslestirme_kuyrugu; rakip eslestirme_kuyrugu; sid uuid;
begin
  update eslestirme_kuyrugu set son_gorulme = now()
    where user_id = auth.uid();
  delete from eslestirme_kuyrugu
    where son_gorulme < now() - interval '2 minutes';
  select * into ben from eslestirme_kuyrugu
    where user_id = auth.uid() for update skip locked;
  if not found then return null; end if;
  select * into rakip from eslestirme_kuyrugu
    where user_id <> ben.user_id
      and mod = ben.mod and masa_kod = ben.masa_kod
      and abs(elo - ben.elo) <= 250
      and son_gorulme > now() - interval '12 seconds'
    order by created_at
    limit 1 for update skip locked;
  if not found then return null; end if;
  if rakip.created_at <= ben.created_at then
    sid := seri_eslesti(rakip.user_id, ben.user_id, ben.mod, ben.masa_kod);
  else
    sid := seri_eslesti(ben.user_id, rakip.user_id, ben.mod, ben.masa_kod);
  end if;
  return sid;
end $$;
