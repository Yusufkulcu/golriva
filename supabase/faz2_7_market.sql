-- ============================================================
-- GOLRIVA FAZ 2.7 — MARKET ÜRÜN YÖNETİMİ
-- Paketler artık tabloda: admin panelden eklenir/kapatılır,
-- uygulama listeyi sunucudan çeker, kod değişikliği gerekmez.
-- faz2_6_hesap üzerine, idempotent.
-- ============================================================

create table if not exists urunler (
  kod         text primary key,          -- magaza konsolundaki urun kimligi
  ad          text not null,
  riva        integer not null check (riva > 0),
  aktif       boolean not null default true,
  sira        integer not null default 0,
  created_at  timestamptz not null default now()
);
insert into urunler (kod, ad, riva, sira) values
  ('riva_500',  'Başlangıç', 500,  1),
  ('riva_1500', 'Popüler',   1500, 2),
  ('riva_5000', 'Kral',      5000, 3)
on conflict (kod) do nothing;

alter table urunler enable row level security;
do $$ begin
  create policy p_urun_oku on urunler for select using (true);
exception when duplicate_object then null; end $$;

-- satin_alma_odul v2: odul miktari SABIT LISTEDEN degil URUNLER tablosundan.
-- (kapali/aktif olmayan urun reddedilir; benzersiz islem kisiti ayni kalir)
create or replace function satin_alma_odul(magaza_adi text, urun_kodu text, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare odul integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if islem_id is null or length(trim(islem_id)) < 8 then
    raise exception 'geçersiz işlem';
  end if;
  select riva into odul from urunler where kod = urun_kodu and aktif;
  if odul is null then raise exception 'bilinmeyen ürün'; end if;
  insert into satin_almalar (user_id, magaza, urun, islem_id, miktar)
    values (auth.uid(), magaza_adi, urun_kodu, islem_id, odul);
  insert into defter (user_id, tip, miktar, aciklama)
    values (auth.uid(), 'paket', odul, magaza_adi || ':' || urun_kodu || ':' || islem_id);
  return odul;
end $$;
grant execute on function satin_alma_odul(text, text, text) to authenticated;

notify pgrst, 'reload schema';
