-- ============================================================
-- GOLRIVA FAZ 2.4 — Arkadaşlar + Davet Kodu + Haftalık Sıralama
-- supabase_sema_v2 + faz2..faz2_3b üzerine uygulanır (idempotent).
-- İlke değişmez: istemci tabloya YAZMAZ; her yazma SECURITY DEFINER RPC.
-- ============================================================

-- ---------- 1. ARKADAŞLAR ----------
-- Karşılıklı model: ekleme anında iki yönlü kayıt (istek/onay yok — MVP).
create table if not exists arkadaslar (
  user_id     uuid not null references profiller(id) on delete cascade,
  arkadas_id  uuid not null references profiller(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, arkadas_id),
  check (user_id <> arkadas_id)
);
alter table arkadaslar enable row level security;
do $$ begin
  create policy p_arkadas_oku on arkadaslar for select using (user_id = auth.uid());
exception when duplicate_object then null; end $$;

-- Kullanıcı adıyla arkadaş ekle (büyük/küçük harf duyarsız).
create or replace function arkadas_ekle(ad text) returns void
language plpgsql security definer set search_path = public as $$
declare hedef uuid;
begin
  select id into hedef from profiller where lower(kullanici_adi) = lower(ad);
  if hedef is null then raise exception 'kullanıcı bulunamadı'; end if;
  if hedef = auth.uid() then raise exception 'kendini ekleyemezsin'; end if;
  insert into arkadaslar (user_id, arkadas_id) values
    (auth.uid(), hedef), (hedef, auth.uid())
  on conflict do nothing;
end $$;

create or replace function arkadas_sil(ad text) returns void
language plpgsql security definer set search_path = public as $$
declare hedef uuid;
begin
  select id into hedef from profiller where lower(kullanici_adi) = lower(ad);
  if hedef is null then return; end if;
  delete from arkadaslar where (user_id = auth.uid() and arkadas_id = hedef)
                            or (user_id = hedef and arkadas_id = auth.uid());
end $$;

-- Arkadaş listesi: ad + elo + lig (sıralama ARKADAŞLAR filtresi de bunu kullanır).
create or replace function arkadas_listesi()
returns table (kullanici_adi text, elo integer, lig_kod text)
language sql security definer set search_path = public stable as $$
  select p.kullanici_adi, p.elo, p.lig_kod
  from arkadaslar a join profiller p on p.id = a.arkadas_id
  where a.user_id = auth.uid()
  order by p.elo desc, p.kullanici_adi
$$;

-- ---------- 2. HAFTALIK SIRALAMA ----------
-- Son 7 günde KAZANILAN ranked seri sayısına göre (dostluk sayılmaz).
-- seriler RLS'i yalnız katılımcıya açık olduğundan RPC şart (definer).
create or replace function haftalik_siralama()
returns table (kullanici_adi text, sayi bigint)
language sql security definer set search_path = public stable as $$
  select p.kullanici_adi, count(*) as sayi
  from seriler s join profiller p on p.id = s.kazanan
  where s.durum = 'bitti' and not s.dostluk
    and coalesce(s.finished_at, s.created_at) > now() - interval '7 days'
  group by p.kullanici_adi
  order by sayi desc, p.kullanici_adi
  limit 50
$$;

-- ---------- 3. DAVET KODU (uzaktan dostluk maçı) ----------
create table if not exists davetler (
  kod         text primary key,
  kurucu      uuid not null references profiller(id) on delete cascade,
  mod         text not null default 'bo1' check (mod in ('bo1','bo3')),
  oyun_kodu   text references oyunlar(kod),     -- null = rulet
  seri_id     uuid references seriler(id),
  durum       text not null default 'bekliyor'
              check (durum in ('bekliyor','eslesti','iptal')),
  created_at  timestamptz not null default now()
);
alter table davetler enable row level security;
do $$ begin
  -- kurucu kendi davetini yoklar (seri_id dolunca maça girer)
  create policy p_davet_oku on davetler for select using (kurucu = auth.uid());
exception when duplicate_object then null; end $$;

-- Davet kur: kullanıcı başına tek aktif davet; kod karışmayan alfabeden.
create or replace function davet_olustur(md text, oyun text)
returns text
language plpgsql security definer set search_path = public as $$
declare k text; harfler text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ'; i integer;
begin
  if md not in ('bo1','bo3') then raise exception 'geçersiz mod'; end if;
  if oyun is not null and not exists (select 1 from oyunlar where kod = oyun) then
    raise exception 'oyun yok';
  end if;
  -- eski bekleyen davetlerim iptal (tek aktif davet kuralı)
  update davetler set durum = 'iptal'
    where kurucu = auth.uid() and durum = 'bekliyor';
  loop
    k := 'GLR-';
    for i in 1..4 loop
      k := k || substr(harfler, 1 + floor(random() * length(harfler))::int, 1);
    end loop;
    exit when not exists (select 1 from davetler where kod = k);
  end loop;
  insert into davetler (kod, kurucu, mod, oyun_kodu) values (k, auth.uid(), md, oyun);
  return k;
end $$;

-- Koda katıl: davet kilitlenir, dostluk serisi kurulur (Riva/Elo yok).
create or replace function davet_katil(k text) returns uuid
language plpgsql security definer set search_path = public as $$
declare d davetler; sid uuid;
begin
  select * into d from davetler
    where kod = upper(trim(k)) for update;
  if not found or d.durum <> 'bekliyor'
     or d.created_at < now() - interval '30 minutes' then
    raise exception 'davet bulunamadı';
  end if;
  if d.kurucu = auth.uid() then raise exception 'kendi davetine katılamazsın'; end if;
  sid := dostluk_seri(d.kurucu, auth.uid(), d.mod, d.oyun_kodu);
  update davetler set durum = 'eslesti', seri_id = sid where kod = d.kod;
  return sid;
end $$;

-- Davetten vazgeç (ekrandan çıkınca).
create or replace function davet_iptal() returns void
language plpgsql security definer set search_path = public as $$
begin
  update davetler set durum = 'iptal'
    where kurucu = auth.uid() and durum = 'bekliyor';
end $$;

-- Eski davet çöpü (fırsatçı temizlik — davet_olustur çağrısında da çalışır).
create or replace function davet_temizle() returns void
language sql security definer set search_path = public as $$
  update davetler set durum = 'iptal'
  where durum = 'bekliyor' and created_at < now() - interval '30 minutes'
$$;

-- ---------- 4. YETKİLER ----------
-- dostluk_seri yalnız sunucu içi (davet_katil çağırır) — istemciden kapalı.
revoke all on function dostluk_seri(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function arkadas_ekle(text)      to authenticated;
grant execute on function arkadas_sil(text)       to authenticated;
grant execute on function arkadas_listesi()       to authenticated;
grant execute on function haftalik_siralama()     to anon, authenticated;
grant execute on function davet_olustur(text, text) to authenticated;
grant execute on function davet_katil(text)       to authenticated;
grant execute on function davet_iptal()           to authenticated;
grant execute on function davet_temizle()         to authenticated;
