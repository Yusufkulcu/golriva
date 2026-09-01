-- ============================================================
-- GOLRIVA FAZ 2.29 — HAZIRLIK EKRANINDA "RAKİP GELMEDİ" HAKEMİ
-- SORUN: maç bulunduktan / BO3'te bir sonraki maça geçildikten sonra
--   rakip hiç bağlanmazsa (uygulamayı kapattı) bekleyen oyuncu süresiz
--   "bağlanıyor…" ekranında kalıyordu; tek çıkış kendini hükmen mağlup
--   etmekti. Sunucu hamle bazlı süpürmeyi (3 dk) yalnız oyundaki
--   maçlar için yapıyordu.
-- ÇÖZÜM: hazirlik_hukmen(mid) — SUNUCU doğrular:
--   * çağıran maçın katılımcısı ve 'hazir' sinyalini göndermiş,
--   * rakibin 'hazir' sinyali YOK,
--   * bekleme süresi doldu: maç oluşturulduğundan / çağıranın hazır
--     anından beri en az 60 sn geçmiş (sunucu saati — istemci saati
--     ileri alınarak kandırılamaz),
--   → maç çağıranın lehine hükmen kapanır (mac_sonuc → seri akışı).
-- faz2_2 üzerine, idempotent.
-- ============================================================

create or replace function hazirlik_hukmen(mid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare mc maclar; s seriler; rakip uuid;
        benim_hazir timestamptz; rakip_hazir timestamptz;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  select * into mc from maclar where id = mid and durum = 'oyunda' for update;
  if not found then raise exception 'maç uygun durumda değil'; end if;
  select * into s from seriler where id = mc.seri_id;
  if auth.uid() not in (s.p1, s.p2) then raise exception 'katılımcı değilsin'; end if;
  rakip := case when auth.uid() = s.p1 then s.p2 else s.p1 end;

  select min(sunucu_ts) into benim_hazir from hamleler
    where mac_id = mid and user_id = auth.uid() and icerik->>'tip' = 'hazir';
  if benim_hazir is null then raise exception 'önce hazır sinyali gerekli'; end if;

  select min(sunucu_ts) into rakip_hazir from hamleler
    where mac_id = mid and user_id = rakip and icerik->>'tip' = 'hazir';
  if rakip_hazir is not null then raise exception 'rakip bağlandı'; end if;

  if now() < greatest(mc.created_at, benim_hazir) + interval '60 seconds' then
    raise exception 'süre dolmadı';
  end if;

  perform mac_sonuc(mid, auth.uid()); -- hükmen: bekleyen kazanır
end $$;
revoke all on function hazirlik_hukmen(uuid) from public, anon;
grant execute on function hazirlik_hukmen(uuid) to authenticated;

notify pgrst, 'reload schema';
