-- ============================================================
-- GOLRIVA FAZ 2.21 — TEK REKLAM LİMİTİ (kullanıcı kararı)
--   HER ödüllü reklam izlemesi (mağaza +50 VE maç sonu 2x/iade)
--   admin paneldeki TEK günlük limitten düşer: ayarlar.gunluk_reklam.
--   Sayaç: reklam_gosterimleri (tur: 'magaza' | 'mac_sonu').
--   reklam_gosterim_hakki() zaten tüm satırları saydığı için kalan hak
--   iki akış için de ortak döner — istemci teklifi buna göre gizler.
--   (Mağazadaki eski sabit 10/gün tavanı KALDIRILDI — tek kaynak admin.)
-- faz2_5 + faz2_10 + faz2_20 üzerine, idempotent.
-- ============================================================

-- MAĞAZA ödüllü reklamı: tavan artık admin ayarından; gösterim sayaca işler.
create or replace function reklam_odul_al(ag_adi text, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare bugun integer; odul integer := 50; limit_ integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if islem_id is null or length(trim(islem_id)) < 8 then
    raise exception 'geçersiz işlem';
  end if;
  limit_ := reklam_ayari();
  select count(*) into bugun from reklam_gosterimleri
    where user_id = auth.uid() and created_at >= date_trunc('day', now());
  if bugun >= limit_ then raise exception 'günlük reklam tavanı doldu'; end if;
  insert into reklam_odulleri (user_id, ag, ssv_islem_id, miktar)
    values (auth.uid(), ag_adi, islem_id, odul);
  insert into reklam_gosterimleri (user_id, tur) values (auth.uid(), 'magaza');
  insert into defter (user_id, tip, miktar, aciklama)
    values (auth.uid(), 'reklam', odul, ag_adi || ':' || islem_id);
  return odul;
end $$;

-- MAÇ SONU ödüllü reklamı: aynı ortak limitten düşer.
create or replace function mac_reklam_odul(sid uuid, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare s seriler; m masalar; odul integer; bugun integer; limit_ integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if islem_id is null or length(trim(islem_id)) < 8 then
    raise exception 'geçersiz işlem';
  end if;
  limit_ := reklam_ayari();
  select count(*) into bugun from reklam_gosterimleri
    where user_id = auth.uid() and created_at >= date_trunc('day', now());
  if bugun >= limit_ then raise exception 'günlük reklam tavanı doldu'; end if;
  select * into s from seriler where id = sid;
  if not found then raise exception 'seri bulunamadı'; end if;
  if auth.uid() not in (s.p1, s.p2) then raise exception 'bu seride değilsin'; end if;
  if s.durum <> 'bitti' then raise exception 'seri bitmedi'; end if;
  if s.dostluk then raise exception 'bu seride Riva işlemedi'; end if;
  if s.kazanan is null then
    raise exception 'seri berabere — girişler zaten iade edildi';
  end if;
  if s.finished_at < now() - interval '1 hour' then
    raise exception 'ödül penceresi kapandı';
  end if;
  select * into m from masalar where kod = s.masa_kod;
  if s.kazanan = auth.uid() then
    odul := case when s.mod = 'bo3' then m.kazanan_net_bo3
                 else m.kazanan_net end;          -- kazancı ikiye katla
  else
    odul := case when s.mod = 'bo3' then m.giris_bo3
                 else m.giris end;                -- kaybı geri al
  end if;
  begin
    insert into seri_reklam_odulleri (seri_id, user_id, miktar, ssv_islem_id)
      values (sid, auth.uid(), odul, islem_id);
  exception when unique_violation then
    raise exception 'bu seri için ödül zaten alındı';
  end;
  insert into reklam_gosterimleri (user_id, tur) values (auth.uid(), 'mac_sonu');
  insert into defter (user_id, tip, miktar, seri_id, aciklama)
    values (auth.uid(), 'reklam', odul, sid,
            case when s.kazanan = auth.uid()
                 then 'maç sonu 2x' else 'maç sonu iade' end);
  return odul;
end $$;

notify pgrst, 'reload schema';
