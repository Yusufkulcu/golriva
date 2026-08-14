-- ============================================================
-- GOLRIVA FAZ 2.24 — ŞİKAYET + ENGELLEME (Apple 1.2 uyumu)
--   App Store kuralı: kullanıcı üretimi içerik (kullanıcı adları,
--   lig adları, davetler) olan uygulamada ŞİKAYET ve ENGELLEME
--   mekanizması zorunludur.
--   * sikayetler  — sebepli bildirim; panelden incelenir
--   * engellemeler — tek yönlü engel; İKİ YÖNLÜ etki eder:
--       - arkadaş eklenemez (mevcut arkadaşlık + istekler silinir)
--       - hedefli davet kurulamaz / bekleyenler görünmez
--       - davet koduna katılamaz
--       - ranked eşleşmede denk gelmezler
--       - engellinin kurduğu arkadaş ligine katılamaz
--   Engel bilgisi karşı tarafa SIZDIRILMAZ: o tarafta her şey
--   'bulunamadı' gibi görünür.
-- faz2_15 + faz2_14 + faz2_3 + faz2_19 üzerine, idempotent.
-- ============================================================

-- ---------- TABLOLAR ----------

create table if not exists engellemeler (
  engelleyen  uuid not null references profiller(id) on delete cascade,
  engellenen  uuid not null references profiller(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (engelleyen, engellenen),
  check (engelleyen <> engellenen)
);
alter table engellemeler enable row level security;
-- istemci tabloya dokunmaz; her şey RPC üzerinden (politika yok).

create table if not exists sikayetler (
  id              bigint generated always as identity primary key,
  sikayet_eden    uuid not null references profiller(id) on delete cascade,
  sikayet_edilen  uuid not null references profiller(id) on delete cascade,
  sebep           text not null check (sebep in
                    ('uygunsuz_ad','hakaret','hile','spam','diger')),
  detay           text,
  durum           text not null default 'yeni' check (durum in
                    ('yeni','incelendi','kapatildi')),
  created_at      timestamptz not null default now(),
  check (sikayet_eden <> sikayet_edilen)
);
alter table sikayetler enable row level security;
-- panel service_role ile okur/günceller (RLS'i aşar); istemciye kapalı.

-- ---------- YARDIMCI: iki kişi arasında engel var mı? ----------
create or replace function engel_var(a uuid, b uuid) returns boolean
language sql stable as $$
  select exists (select 1 from engellemeler
                  where (engelleyen = a and engellenen = b)
                     or (engelleyen = b and engellenen = a))
$$;
revoke all on function engel_var(uuid, uuid) from public, anon, authenticated;

-- ---------- ENGELLE / ENGEL KALDIR / LİSTEM ----------

-- Engelle: kayıt + mevcut bağların temizliği (arkadaşlık, istekler,
-- bekleyen hedefli davetler). Engel TEK yönlü saklanır, İKİ yönlü etki eder.
create or replace function kisi_engelle(ad text) returns void
language plpgsql security definer set search_path = public as $$
declare hedef_id uuid;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  select id into hedef_id from profiller where lower(kullanici_adi) = lower(ad);
  if hedef_id is null then raise exception 'kullanıcı bulunamadı'; end if;
  if hedef_id = auth.uid() then raise exception 'kendini engelleyemezsin'; end if;
  insert into engellemeler (engelleyen, engellenen)
    values (auth.uid(), hedef_id)
  on conflict do nothing;
  -- bağları kopar
  delete from arkadaslar
    where (user_id = auth.uid() and arkadas_id = hedef_id)
       or (user_id = hedef_id and arkadas_id = auth.uid());
  delete from arkadas_istekleri
    where (isteyen = auth.uid() and hedef = hedef_id)
       or (isteyen = hedef_id and hedef = auth.uid());
  update davetler set durum = 'iptal'
    where durum = 'bekliyor'
      and ((kurucu = auth.uid() and hedef = hedef_id)
        or (kurucu = hedef_id and hedef = auth.uid()));
end $$;
grant execute on function kisi_engelle(text) to authenticated;

create or replace function engel_kaldir(ad text) returns void
language plpgsql security definer set search_path = public as $$
declare hedef_id uuid;
begin
  select id into hedef_id from profiller where lower(kullanici_adi) = lower(ad);
  if hedef_id is null then return; end if;
  delete from engellemeler
    where engelleyen = auth.uid() and engellenen = hedef_id;
end $$;
grant execute on function engel_kaldir(text) to authenticated;

create or replace function engellilerim()
returns table (kullanici_adi text, created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select p.kullanici_adi, e.created_at
  from engellemeler e join profiller p on p.id = e.engellenen
  where e.engelleyen = auth.uid()
  order by e.created_at desc
$$;
grant execute on function engellilerim() to authenticated;

-- ---------- ŞİKAYET ----------
-- Kurallar: geçerli sebep; kişi başı günde en çok 10 şikayet;
-- aynı kişiye 24 saatte 1 şikayet (spam koruması).
create or replace function sikayet_gonder(ad text, sebep_p text,
                                          detay_p text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare hedef_id uuid;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if sebep_p not in ('uygunsuz_ad','hakaret','hile','spam','diger') then
    raise exception 'geçersiz sebep';
  end if;
  select id into hedef_id from profiller where lower(kullanici_adi) = lower(ad);
  if hedef_id is null then raise exception 'kullanıcı bulunamadı'; end if;
  if hedef_id = auth.uid() then raise exception 'kendini şikayet edemezsin'; end if;
  if (select count(*) from sikayetler
       where sikayet_eden = auth.uid()
         and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'günlük şikayet sınırına ulaştın';
  end if;
  if exists (select 1 from sikayetler
              where sikayet_eden = auth.uid()
                and sikayet_edilen = hedef_id
                and created_at > now() - interval '24 hours') then
    raise exception 'bu kullanıcıyı zaten bildirdin — ekip inceleyecek';
  end if;
  insert into sikayetler (sikayet_eden, sikayet_edilen, sebep, detay)
    values (auth.uid(), hedef_id, sebep_p, left(trim(detay_p), 500));
end $$;
grant execute on function sikayet_gonder(text, text, text) to authenticated;

-- ============================================================
-- ENGELİN UYGULANDIĞI NOKTALAR — mevcut fonksiyonların v2'leri
-- (gövdeler güncel sürümlerden alındı, yalnız engel kontrolü eklendi)
-- ============================================================

-- arkadas_ekle v3 (faz2_15 v2 + engel): engelliye istek atılamaz.
-- Ben engellediysem açık mesaj; o beni engellediyse 'bulunamadı' (sızdırma yok).
create or replace function arkadas_ekle(ad text) returns text
language plpgsql security definer set search_path = public as $$
declare hedef_id uuid;
begin
  select id into hedef_id from profiller where lower(kullanici_adi) = lower(ad);
  if hedef_id is null then raise exception 'kullanıcı bulunamadı'; end if;
  if hedef_id = auth.uid() then raise exception 'kendini ekleyemezsin'; end if;
  if exists (select 1 from engellemeler
              where engelleyen = auth.uid() and engellenen = hedef_id) then
    raise exception 'bu kullanıcıyı engelledin — önce engeli kaldır';
  end if;
  if exists (select 1 from engellemeler
              where engelleyen = hedef_id and engellenen = auth.uid()) then
    raise exception 'kullanıcı bulunamadı';
  end if;
  if exists (select 1 from arkadaslar
              where user_id = auth.uid() and arkadas_id = hedef_id) then
    return 'arkadas';
  end if;
  if exists (select 1 from arkadas_istekleri
              where isteyen = hedef_id and hedef = auth.uid()) then
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

-- gelen_arkadas_istekleri v2: engelli tarafların isteği görünmez.
create or replace function gelen_arkadas_istekleri()
returns table (kullanici_adi text, created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select p.kullanici_adi, i.created_at
  from arkadas_istekleri i join profiller p on p.id = i.isteyen
  where i.hedef = auth.uid()
    and not engel_var(i.isteyen, auth.uid())
  order by i.created_at desc
$$;

-- davet_olustur2 v2 (faz2_14 + engel): engelliye hedefli davet kurulamaz.
create or replace function davet_olustur2(md text, oyunlar_j jsonb default null,
                                          hedef_ad text default null)
returns text
language plpgsql security definer set search_path = public as $$
declare k text; harfler text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ'; i integer;
        hedef_id uuid; tek text; e jsonb;
begin
  if md not in ('bo1','bo3') then raise exception 'geçersiz mod'; end if;
  if oyunlar_j is not null then
    if jsonb_typeof(oyunlar_j) <> 'array'
       or jsonb_array_length(oyunlar_j) not between 1 and 3 then
      raise exception 'geçersiz oyun listesi';
    end if;
    for e in select * from jsonb_array_elements(oyunlar_j) loop
      if not exists (select 1 from oyunlar where kod = (e #>> '{}')) then
        raise exception 'oyun yok: %', (e #>> '{}');
      end if;
    end loop;
    if jsonb_array_length(oyunlar_j) = 1 then tek := oyunlar_j ->> 0; end if;
  end if;
  if hedef_ad is not null then
    select id into hedef_id from profiller
      where lower(kullanici_adi) = lower(hedef_ad);
    if hedef_id is null then raise exception 'kullanıcı bulunamadı'; end if;
    if engel_var(auth.uid(), hedef_id) then
      raise exception 'kullanıcı bulunamadı';
    end if;
    if not exists (select 1 from arkadaslar
                    where user_id = auth.uid() and arkadas_id = hedef_id) then
      raise exception 'önce arkadaş eklemelisin';
    end if;
  end if;
  update davetler set durum = 'iptal'
    where kurucu = auth.uid() and durum = 'bekliyor';
  loop
    k := 'GLR-';
    for i in 1..4 loop
      k := k || substr(harfler, 1 + floor(random() * length(harfler))::int, 1);
    end loop;
    exit when not exists (select 1 from davetler where kod = k);
  end loop;
  insert into davetler (kod, kurucu, mod, oyun_kodu, oyunlar, hedef)
    values (k, auth.uid(), md, tek, oyunlar_j, hedef_id);
  return k;
end $$;

-- davet_katil v3 (faz2_14 v2 + engel): engelli, koda da katılamaz.
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
  if d.hedef is not null and d.hedef <> auth.uid() then
    raise exception 'bu davet başka bir oyuncuya özel';
  end if;
  if engel_var(d.kurucu, auth.uid()) then
    raise exception 'davet bulunamadı';
  end if;
  sid := dostluk_seri(d.kurucu, auth.uid(), d.mod, d.oyun_kodu, d.oyunlar);
  update davetler set durum = 'eslesti', seri_id = sid where kod = d.kod;
  return sid;
end $$;

-- gelen_davetler v2 (faz2_14 + engel süzgeci).
create or replace function gelen_davetler()
returns table (kod text, kurucu_ad text, mod text, oyunlar jsonb,
               created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select d.kod, p.kullanici_adi, d.mod, d.oyunlar, d.created_at
  from davetler d join profiller p on p.id = d.kurucu
  where d.hedef = auth.uid() and d.durum = 'bekliyor'
    and d.created_at > now() - interval '30 minutes'
    and not engel_var(d.kurucu, auth.uid())
  order by d.created_at desc
$$;

-- eslesme_dene v2 (faz2_3a + engel): ranked eşleşmede engelli rakip atlanır.
create or replace function eslesme_dene() returns uuid
language plpgsql security definer set search_path = public as $$
declare ben eslestirme_kuyrugu; rakip eslestirme_kuyrugu; sid uuid;
begin
  update eslestirme_kuyrugu set son_gorulme = now()
    where user_id = auth.uid();
  delete from eslestirme_kuyrugu
    where son_gorulme < now() - interval '2 minutes';
  select * into ben from eslestirme_kuyrugu
    where user_id = auth.uid() for update skip locked;
  if not found then return null; end if;
  select * into rakip from eslestirme_kuyrugu
    where user_id <> ben.user_id
      and mod = ben.mod and masa_kod = ben.masa_kod
      and abs(elo - ben.elo) <= 250
      and son_gorulme > now() - interval '12 seconds'
      and not engel_var(user_id, ben.user_id)
    order by created_at
    limit 1 for update skip locked;
  if not found then return null; end if;
  if rakip.created_at <= ben.created_at then
    sid := seri_eslesti(rakip.user_id, ben.user_id, ben.mod, ben.masa_kod);
  else
    sid := seri_eslesti(ben.user_id, rakip.user_id, ben.mod, ben.masa_kod);
  end if;
  return sid;
end $$;

-- alig_katil v2 (faz2_19 + engel): kurucusuyla engelli olduğun lige
-- katılamazsın ('lig bulunamadı' — sızdırma yok).
create or replace function alig_katil(k text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l arkadas_ligleri; bak integer; sayi integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  select * into l from arkadas_ligleri where kod = upper(trim(k)) for update;
  if not found then raise exception 'lig bulunamadı'; end if;
  if engel_var(l.kurucu, auth.uid()) then raise exception 'lig bulunamadı'; end if;
  if l.durum <> 'acik' then raise exception 'lig katılıma kapalı'; end if;
  if exists (select 1 from alig_uyeler where lig_id = l.id and user_id = auth.uid()) then
    raise exception 'zaten bu ligdesin';
  end if;
  if alig_aktif_sayim(auth.uid()) >= 3 then
    raise exception 'aynı anda en fazla 3 aktif ligde olabilirsin';
  end if;
  if l.giris > 0 then
    select bakiye into bak from cuzdanlar where user_id = auth.uid() for update;
    if bak < l.giris then raise exception 'yetersiz bakiye'; end if;
    insert into defter (user_id, tip, miktar, aciklama)
      values (auth.uid(), 'lig_giris', -l.giris, l.kod);
  end if;
  insert into alig_uyeler (lig_id, user_id) values (l.id, auth.uid());
  update arkadas_ligleri set havuz = havuz + l.giris where id = l.id;
  select count(*) into sayi from alig_uyeler where lig_id = l.id;
  if sayi >= l.boyut then
    update arkadas_ligleri set durum = 'aktif', baslama_at = now(),
        bitis_at = now() + make_interval(days => l.sure_gun)
      where id = l.id;
    perform alig_fikstur_cek(l.id);
  end if;
  return l.id;
end $$;

notify pgrst, 'reload schema';
