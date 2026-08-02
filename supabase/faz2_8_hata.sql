-- ============================================================
-- GOLRIVA FAZ 2.8 — MERKEZİ HATA RAPORLAMA
-- Kural: kullanıcı ASLA teknik hata görmez; detay buraya düşer,
-- admin panelinin HATALAR sekmesinde okunur.
-- ============================================================

create table if not exists hata_kayitlari (
  id          bigint generated always as identity primary key,
  user_id     uuid,                      -- oturum yoksa null
  sayfa       text not null,             -- 'magaza._satinAl' gibi konum
  mesaj       text not null,             -- teknik mesaj + kisa yigin izi
  surum       text,
  platform    text,
  created_at  timestamptz not null default now()
);
create index if not exists hata_zaman on hata_kayitlari (created_at desc);

alter table hata_kayitlari enable row level security;
-- istemciye OKUMA yok (yalniz panel/service_role okur); yazma RPC ile.

create or replace function hata_bildir(
  sayfa_p text, mesaj_p text, surum_p text, platform_p text) returns void
language plpgsql security definer set search_path = public as $$
begin
  -- tasma korumalari: uzunluk kirp + kullanici basina gunde 100 kayit
  if auth.uid() is not null then
    if (select count(*) from hata_kayitlari
        where user_id = auth.uid()
          and created_at >= date_trunc('day', now())) >= 100 then
      return; -- sessizce yut — raporlayici asla hata uretmez
    end if;
  end if;
  insert into hata_kayitlari (user_id, sayfa, mesaj, surum, platform)
  values (auth.uid(),
          left(coalesce(sayfa_p, '?'), 120),
          left(coalesce(mesaj_p, '?'), 1000),
          left(surum_p, 30), left(platform_p, 20));
end $$;
grant execute on function hata_bildir(text, text, text, text) to anon, authenticated;

notify pgrst, 'reload schema';
