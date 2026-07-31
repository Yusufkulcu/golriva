-- ============================================================
-- GOLRIVA FAZ 2.5 — Ödüllü Reklam (AdMob) sunucu tarafı
-- faz2_4_ek.sql üzerine uygulanır (idempotent).
-- ============================================================

-- GÜVENLİ ödül RPC'si: kimlik auth.uid()'den alınır — istemci uid İLETEMEZ.
-- (Eski reklam_odul_ver(u uuid, ...) imzası kimlik parametresi aldığı için
-- istemciye kapatılır; yalnız bu yeni imza açıktır.)
-- Kurallar sunucuda: ödül 50 RIVA, günlük tavan 10; (ag, islem_id) benzersiz
-- kısıtı aynı reklamın iki kez ödüllenmesini engeller. Gerçek SSV
-- (AdMob sunucu doğrulaması) Faz 3'te bu fonksiyonun önüne eklenecek.
create or replace function reklam_odul_al(ag_adi text, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare bugun integer; odul integer := 50; tavan integer := 10;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if islem_id is null or length(trim(islem_id)) < 8 then
    raise exception 'geçersiz işlem';
  end if;
  select count(*) into bugun from reklam_odulleri
    where user_id = auth.uid() and created_at >= date_trunc('day', now());
  if bugun >= tavan then raise exception 'günlük reklam tavanı doldu'; end if;
  insert into reklam_odulleri (user_id, ag, ssv_islem_id, miktar)
    values (auth.uid(), ag_adi, islem_id, odul);
  insert into defter (user_id, tip, miktar, aciklama)
    values (auth.uid(), 'reklam', odul, ag_adi || ':' || islem_id);
  return odul;
end $$;

revoke all on function reklam_odul_ver(uuid, text, text) from public, anon, authenticated;
grant execute on function reklam_odul_al(text, text) to authenticated;

notify pgrst, 'reload schema';
