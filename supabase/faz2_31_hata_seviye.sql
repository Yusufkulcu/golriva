-- ============================================================
-- GOLRIVA FAZ 2.31 — HATA KAYITLARINA SEVİYE
--   Panel artık kayıtları kritik / hata / uyari / bilgi olarak böler
--   (kullanıcı isteği). İstemci seviyeyi mesaja bakarak kendisi belirler
--   (hata_raporu.dart); eski istemciler seviye göndermez → 'hata'.
-- faz2_8 üzerine, idempotent.
-- ============================================================

alter table hata_kayitlari
  add column if not exists seviye text not null default 'hata'
  check (seviye in ('kritik','hata','uyari','bilgi'));
create index if not exists hata_seviye_zaman
  on hata_kayitlari (seviye, created_at desc);

-- eski 4 parametreli imza düşer; yeni imzada seviye VARSAYILANLI —
-- eski istemcilerin 4 parametreli çağrısı da bu fonksiyona düşer.
drop function if exists hata_bildir(text, text, text, text);
create or replace function hata_bildir(
  sayfa_p text, mesaj_p text, surum_p text, platform_p text,
  seviye_p text default 'hata') returns void
language plpgsql security definer set search_path = public as $$
declare sv text;
begin
  if auth.uid() is not null then
    if (select count(*) from hata_kayitlari
        where user_id = auth.uid()
          and created_at >= date_trunc('day', now())) >= 100 then
      return; -- tasma korumasi: sessizce yut
    end if;
  end if;
  sv := case when seviye_p in ('kritik','hata','uyari','bilgi')
             then seviye_p else 'hata' end;
  insert into hata_kayitlari (user_id, sayfa, mesaj, surum, platform, seviye)
  values (auth.uid(),
          left(coalesce(sayfa_p, '?'), 120),
          left(coalesce(mesaj_p, '?'), 1000),
          left(surum_p, 30), left(platform_p, 20), sv);
end $$;
grant execute on function hata_bildir(text, text, text, text, text)
  to anon, authenticated;

-- Mevcut kayıtları da geriye dönük sınıflandır (panel hemen bölünmüş görsün)
update hata_kayitlari set seviye = 'bilgi'
 where seviye = 'hata' and (
   mesaj ilike '%Bad file descriptor%' or mesaj ilike '%SocketException%'
   or mesaj ilike '%apns-token-not-set%' or mesaj ilike '%maç uygun değil%'
   or mesaj ilike '%No ad to show%');
update hata_kayitlari set seviye = 'uyari'
 where seviye = 'hata' and (
   mesaj ilike '%issued at future%' or mesaj ilike '%validation_failed%'
   or mesaj ilike '%Invalid login%' or mesaj ilike '%23505%');
update hata_kayitlari set seviye = 'kritik'
 where seviye = 'hata' and (
   sayfa like 'global.%' or mesaj ilike '%Null check operator%'
   or mesaj ilike '%RangeError%' or mesaj ilike '%NoSuchMethodError%'
   or mesaj ilike '%is not a subtype%');

notify pgrst, 'reload schema';
