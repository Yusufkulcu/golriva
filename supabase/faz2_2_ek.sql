-- =============================================================
-- GOLRIVA FAZ 2.2 EK — cevrimici oynanis senkronu (30 Tem 2026)
-- faz2_ek.sql SONRASINDA calistir.
-- =============================================================

-- Faz 2.2'de rulet havuzu: SIRA-TABANLI 8 oyun. Bayrak Yarisi (refleks/buzz)
-- ve Kariyer Ikizi cevrimici surumu Faz 2.3'te havuza geri girer.
update oyunlar set random_havuz = false
 where kod in ('bayrak_yarisi', 'kariyer_ikizi');

-- HAMLE GONDER: katilimci + mac acik dogrulamasi sunucuda.
-- (mac_id, user_id, hamle_no) UNIQUE — ayni hamle iki kez islenemez.
create or replace function hamle_gonder(mid uuid, no integer, icerik_j jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare mc maclar;
begin
  select mx.* into mc from maclar mx
    join seriler sx on sx.id = mx.seri_id
    where mx.id = mid and mx.durum = 'oyunda'
      and (auth.uid() = sx.p1 or auth.uid() = sx.p2);
  if not found then raise exception 'maç uygun değil ya da katılımcı değilsin'; end if;
  insert into hamleler (mac_id, user_id, hamle_no, icerik)
    values (mid, auth.uid(), no, icerik_j);
end $$;

-- MAC BITIR: katilimci raporlar; ilk gecerli rapor kazanir (mac_sonuc'un
-- for update + durum kilidi cifte islemeyi zaten engeller).
-- NOT (durustluk): istemci raporuna guvenilir — sunucu tarafli oyun motoru
-- Faz 3 isi. Kendi yenilgisini bildirmek ("çekil") her zaman serbest.
create or replace function mac_bitir(mid uuid, kazanan_p uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare sx seriler;
begin
  select s.* into sx from seriler s
    join maclar m on m.seri_id = s.id
    where m.id = mid and (auth.uid() = s.p1 or auth.uid() = s.p2);
  if not found then raise exception 'katılımcı değilsin'; end if;
  if kazanan_p is not null and kazanan_p not in (sx.p1, sx.p2) then
    raise exception 'kazanan seride değil';
  end if;
  perform mac_sonuc(mid, kazanan_p);
end $$;

-- Yetki sikilastirma: ic RPC'ler istemciden CAGRILAMAZ.
revoke all on function mac_sonuc(uuid, uuid) from public, anon, authenticated;
revoke all on function seri_kapat(uuid, uuid) from public, anon, authenticated;
revoke all on function seri_eslesti(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function hamle_gonder(uuid, integer, jsonb) from public, anon;
revoke all on function mac_bitir(uuid, uuid) from public, anon;
grant execute on function hamle_gonder(uuid, integer, jsonb) to authenticated;
grant execute on function mac_bitir(uuid, uuid) to authenticated;
