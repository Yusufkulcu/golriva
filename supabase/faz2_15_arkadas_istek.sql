-- ============================================================
-- GOLRIVA FAZ 2.15 — ARKADAŞLIK İSTEĞİ (onaylı model)
-- Eski MVP: ekleme anında iki yönlü kayıt (onaysız). YENİ KURAL
-- (kullanıcı isteği): ekleme bir İSTEK oluşturur; karşı taraf
-- ONAYLAYINCA arkadaşlık iki yönlü kurulur. Mevcut arkadaşlıklar
-- olduğu gibi kalır. faz2_4 üzerine, idempotent.
-- ============================================================

create table if not exists arkadas_istekleri (
  isteyen     uuid not null references profiller(id) on delete cascade,
  hedef       uuid not null references profiller(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (isteyen, hedef),
  check (isteyen <> hedef)
);
alter table arkadas_istekleri enable row level security;
-- istemci tabloya dokunmaz; okuma da RPC üzerinden (definer) — politika yok.

-- arkadas_ekle v2: arkadaşlık DEĞİL istek oluşturur.
-- Dönüş: 'istek' (gönderildi) | 'arkadas' (zaten arkadaş YA DA karşı taraf
-- zaten bana istek atmıştı → çapraz istek OTOMATİK eşleşir, direkt arkadaş).
drop function if exists arkadas_ekle(text);
create or replace function arkadas_ekle(ad text) returns text
language plpgsql security definer set search_path = public as $$
declare hedef_id uuid;
begin
  select id into hedef_id from profiller where lower(kullanici_adi) = lower(ad);
  if hedef_id is null then raise exception 'kullanıcı bulunamadı'; end if;
  if hedef_id = auth.uid() then raise exception 'kendini ekleyemezsin'; end if;
  if exists (select 1 from arkadaslar
              where user_id = auth.uid() and arkadas_id = hedef_id) then
    return 'arkadas';
  end if;
  if exists (select 1 from arkadas_istekleri
              where isteyen = hedef_id and hedef = auth.uid()) then
    -- o zaten beni eklemek istiyordu: çapraz istek = karşılıklı onay
    delete from arkadas_istekleri
      where (isteyen = hedef_id and hedef = auth.uid())
         or (isteyen = auth.uid() and hedef = hedef_id);
    insert into arkadaslar (user_id, arkadas_id) values
      (auth.uid(), hedef_id), (hedef_id, auth.uid())
    on conflict do nothing;
    return 'arkadas';
  end if;
  insert into arkadas_istekleri (isteyen, hedef)
    values (auth.uid(), hedef_id)
  on conflict do nothing;
  return 'istek';
end $$;
grant execute on function arkadas_ekle(text) to authenticated;

-- İsteğe yanıt: kabul → iki yönlü arkadaşlık; her durumda istek silinir.
create or replace function arkadas_istek_yanit(ad text, kabul boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare isteyen_id uuid;
begin
  select id into isteyen_id from profiller where lower(kullanici_adi) = lower(ad);
  if isteyen_id is null then raise exception 'kullanıcı bulunamadı'; end if;
  if not exists (select 1 from arkadas_istekleri
                  where isteyen = isteyen_id and hedef = auth.uid()) then
    raise exception 'istek bulunamadı';
  end if;
  delete from arkadas_istekleri
    where isteyen = isteyen_id and hedef = auth.uid();
  if kabul then
    insert into arkadaslar (user_id, arkadas_id) values
      (auth.uid(), isteyen_id), (isteyen_id, auth.uid())
    on conflict do nothing;
  end if;
end $$;
grant execute on function arkadas_istek_yanit(text, boolean) to authenticated;

-- Bana gelen bekleyen istekler.
create or replace function gelen_arkadas_istekleri()
returns table (kullanici_adi text, created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select p.kullanici_adi, i.created_at
  from arkadas_istekleri i join profiller p on p.id = i.isteyen
  where i.hedef = auth.uid()
  order by i.created_at desc
$$;
grant execute on function gelen_arkadas_istekleri() to authenticated;

-- arkadas_sil v2: bekleyen istekleri de temizler (iki yönde).
create or replace function arkadas_sil(ad text) returns void
language plpgsql security definer set search_path = public as $$
declare hedef_id uuid;
begin
  select id into hedef_id from profiller where lower(kullanici_adi) = lower(ad);
  if hedef_id is null then return; end if;
  delete from arkadaslar where (user_id = auth.uid() and arkadas_id = hedef_id)
                            or (user_id = hedef_id and arkadas_id = auth.uid());
  delete from arkadas_istekleri
    where (isteyen = auth.uid() and hedef = hedef_id)
       or (isteyen = hedef_id and hedef = auth.uid());
end $$;

notify pgrst, 'reload schema';
