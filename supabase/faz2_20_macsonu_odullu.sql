-- ============================================================
-- GOLRIVA FAZ 2.20 — MAÇ SONU ÖDÜLLÜ REKLAM (kullanıcı kararı)
--   Maç sonu OTOMATİK geçiş reklamı KALDIRILDI. Yerine seri sonucu
--   ekranında İSTEĞE BAĞLI ödüllü reklam teklifi:
--     * Seriyi KAZANAN izlerse net kazancı İKİYE KATLANIR
--       (masa kazanan_net'i kadar ek Riva).
--     * KAYBEDEN izlerse seri girişi GERİ VERİLİR (kayıp sıfırlanır).
--   Kurallar sunucuda: tutar masalar tablosundan hesaplanır, istemci
--   tutar İLETEMEZ; seri başına kişi başı TEK ödül; 1 saatlik pencere;
--   dostluk/lig serilerinde (Riva işlemez) ödül yok; berabere zaten iade.
-- supabase_sema_v2 + faz2_5 üzerine, idempotent.
-- ============================================================

create table if not exists seri_reklam_odulleri (
  seri_id      uuid not null references seriler(id) on delete cascade,
  user_id      uuid not null references profiller(id) on delete cascade,
  miktar       integer not null,
  ag           text not null default 'admob',
  ssv_islem_id text not null,
  created_at   timestamptz not null default now(),
  primary key (seri_id, user_id),
  unique (ag, ssv_islem_id)
);
alter table seri_reklam_odulleri enable row level security;
do $$ begin
  create policy p_seri_reklam_oku on seri_reklam_odulleri
    for select using (user_id = auth.uid());
exception when duplicate_object then null; end $$;

-- Ödül RPC'si: reklam İZLENDİKTEN sonra istemci çağırır.
-- Dönüş: yazılan Riva miktarı.
create or replace function mac_reklam_odul(sid uuid, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare s seriler; m masalar; odul integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if islem_id is null or length(trim(islem_id)) < 8 then
    raise exception 'geçersiz işlem';
  end if;
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
  insert into defter (user_id, tip, miktar, seri_id, aciklama)
    values (auth.uid(), 'reklam', odul, sid,
            case when s.kazanan = auth.uid()
                 then 'maç sonu 2x' else 'maç sonu iade' end);
  return odul;
end $$;
revoke all on function mac_reklam_odul(uuid, text) from public, anon;
grant execute on function mac_reklam_odul(uuid, text) to authenticated;

notify pgrst, 'reload schema';
