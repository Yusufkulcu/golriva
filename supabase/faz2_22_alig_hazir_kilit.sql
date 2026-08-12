-- ============================================================
-- GOLRIVA FAZ 2.22 — ARKADAŞ LİGİ HAZIR KİLİDİ (kullanıcı kararı)
--   Sorun: birden fazla maça "hazırım" denince, rakip BAŞKA maçtayken
--   bile maç kuruluyor ve "maç bulundu" ekranı askıda kalıyordu.
--   Kural: HERKES AYNI ANDA TEK LİG MAÇI OYNAR, TEK MAÇA HAZIR OLUR.
--   1) Devam eden lig maçın varsa yeni maça hazır olamazsın.
--   2) Bir maça hazır deyince diğer bekleyen maçlardaki hazır sinyalin
--      otomatik düşer (tek aktif hazır).
--   3) Maç, ancak İKİ TARAF da başka aktif lig maçında değilse başlar.
-- faz2_19 üzerine, idempotent.
-- ============================================================

create or replace function alig_hazir(mid uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare mc alig_maclar; l arkadas_ligleri; sid uuid; benim1 boolean;
        diger_ts timestamptz; digeri uuid;
begin
  select * into mc from alig_maclar where id = mid for update;
  if not found then raise exception 'maç bulunamadı'; end if;
  if auth.uid() not in (mc.p1, mc.p2) then raise exception 'bu maçta değilsin'; end if;
  select * into l from arkadas_ligleri where id = mc.lig_id;
  if l.durum <> 'aktif' then raise exception 'lig aktif değil'; end if;

  -- (1) TEK MAÇ KURALI: devam eden lig maçın varsa önce onu bitir.
  --     (seriler durumuna da bakılır — kapanmış ama tetikleyiciyi kaçırmış
  --      satır kimseyi süresiz kilitlemesin)
  if exists (select 1 from alig_maclar am
               join seriler s on s.id = am.seri_id
              where am.durum = 'oyunda' and s.durum = 'oyunda'
                and auth.uid() in (am.p1, am.p2)) then
    raise exception 'önce devam eden lig maçını bitir';
  end if;

  if mc.durum = 'bekliyor' then
    benim1 := auth.uid() = mc.p1;
    -- (2) TEK HAZIR KURALI: diğer bekleyen maçlardaki sinyalim düşer.
    update alig_maclar set hazir1_at = null
      where p1 = auth.uid() and durum = 'bekliyor' and id <> mid
        and hazir1_at is not null;
    update alig_maclar set hazir2_at = null
      where p2 = auth.uid() and durum = 'bekliyor' and id <> mid
        and hazir2_at is not null;
    if benim1 then
      update alig_maclar set hazir1_at = now() where id = mid returning * into mc;
    else
      update alig_maclar set hazir2_at = now() where id = mid returning * into mc;
    end if;
    diger_ts := case when benim1 then mc.hazir2_at else mc.hazir1_at end;
    digeri := case when benim1 then mc.p2 else mc.p1 end;
    -- (3) Başlatma: rakip 90 sn penceresinde hazır VE başka aktif lig
    --     maçında DEĞİLSE.
    if diger_ts is not null and diger_ts > now() - interval '90 seconds'
       and not exists (select 1 from alig_maclar am
                         join seriler s on s.id = am.seri_id
                        where am.durum = 'oyunda' and s.durum = 'oyunda'
                          and digeri in (am.p1, am.p2)) then
      sid := dostluk_seri(mc.p1, mc.p2, 'bo1', null, null);
      update alig_maclar set durum = 'oyunda', seri_id = sid
        where id = mid returning * into mc;
    end if;
  end if;
  return jsonb_build_object(
    'durum', mc.durum, 'seri_id', mc.seri_id,
    'hazir1_at', mc.hazir1_at, 'hazir2_at', mc.hazir2_at,
    'sunucu_now', now());
end $$;
grant execute on function alig_hazir(uuid) to authenticated;

notify pgrst, 'reload schema';
