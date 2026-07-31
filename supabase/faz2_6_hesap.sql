-- ============================================================
-- GOLRIVA FAZ 2.6 — Hesap Sistemi Ekleri
-- (avatar + uygulama içi satın alma) — faz2_5 üzerine, idempotent.
-- ============================================================

-- ---------- 1. PROFİL FOTOĞRAFI ----------
alter table profiller add column if not exists avatar_url text;

create or replace function avatar_ayarla(u text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if u is not null and u !~ '^https?://' then raise exception 'geçersiz adres'; end if;
  update profiller set avatar_url = u where id = auth.uid();
end $$;
grant execute on function avatar_ayarla(text) to authenticated;

-- Depolama kovası + kuralları (yalnız Supabase'de çalışır; yerel testte atlanır)
do $$ begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public)
      values ('avatarlar', 'avatarlar', true)
      on conflict (id) do nothing;
    -- herkes okur (public kova), kullanıcı YALNIZ kendi dosyasını yazar:
    -- dosya adı deseni: <uid>.jpg
    begin
      create policy avatar_yukle on storage.objects for insert to authenticated
        with check (bucket_id = 'avatarlar'
                    and name = auth.uid()::text || '.jpg');
    exception when duplicate_object then null; end;
    begin
      create policy avatar_guncelle on storage.objects for update to authenticated
        using (bucket_id = 'avatarlar' and name = auth.uid()::text || '.jpg');
    exception when duplicate_object then null; end;
  end if;
end $$;

-- ---------- 2. UYGULAMA İÇİ SATIN ALMA (Riva paketleri) ----------
-- İstemci mağaza satın alımını bitirince buraya bildirir; (magaza, islem_id)
-- benzersiz kısıtı aynı satın alımın iki kez ödüllenmesini engeller.
-- GERÇEK makbuz doğrulaması (App Store / Play sunucu API'si) Faz 3 işi —
-- o gelene dek bu uç yalnız benzersizlik + sabit ürün tablosuyla korunur.
create table if not exists satin_almalar (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references profiller(id) on delete cascade,
  magaza      text not null check (magaza in ('play','appstore')),
  urun        text not null,
  islem_id    text not null,
  miktar      integer not null,
  created_at  timestamptz not null default now(),
  unique (magaza, islem_id)
);
alter table satin_almalar enable row level security;
do $$ begin
  create policy p_satinalma_oku on satin_almalar for select using (user_id = auth.uid());
exception when duplicate_object then null; end $$;

create or replace function satin_alma_odul(magaza_adi text, urun_kodu text, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare odul integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if islem_id is null or length(trim(islem_id)) < 8 then
    raise exception 'geçersiz işlem';
  end if;
  odul := case urun_kodu
    when 'riva_500'  then 500
    when 'riva_1500' then 1500
    when 'riva_5000' then 5000
    else null end;
  if odul is null then raise exception 'bilinmeyen ürün'; end if;
  insert into satin_almalar (user_id, magaza, urun, islem_id, miktar)
    values (auth.uid(), magaza_adi, urun_kodu, islem_id, odul);
  insert into defter (user_id, tip, miktar, aciklama)
    values (auth.uid(), 'paket', odul, magaza_adi || ':' || urun_kodu || ':' || islem_id);
  return odul;
end $$;
grant execute on function satin_alma_odul(text, text, text) to authenticated;

notify pgrst, 'reload schema';
