-- ============================================================
-- GOLRIVA FAZ 2.19 — ARKADAŞ LİGİ (kullanıcı onaylı spec)
--   * Kurucu katılım ücretini belirler (0 = ücretsiz ya da 100-10.000),
--     herkes eşit öder; lig 4/6/8 kişilik, tek devreli round-robin.
--   * Şampiyon havuzun %80'ini alır, kalan %20 kasaya (2.-3. ödül yok).
--   * Puan: G=3 B=1 M=0. Eşitlikte: ikili maç → az hükmen → ödül bölüşülür.
--   * Fikstür lig dolunca OTOMATİK çekilir; zorunlu saat yok — iki taraf
--     "hazırım" der (90 sn canlı pencere), maç başlar (dostluk serisi bo1,
--     oyunu rulet seçer; Riva/Elo işlemez, sadece lig puanı).
--   * Lig süresini kurucu belirler (3-30 gün). Süre dolunca oynanmamış
--     maçlarda: tek taraf hazır işaretlemişse hükmen onun; ikisi de
--     işaretlemişse berabere; hiçbiri işaretlememişse maç İPTAL (0 puan).
--   * Lig 48 saatte dolmazsa (ya da kurucu açıkken ayrılırsa) iptal + iade.
--   * Terk eden: kalan maçları rakiplerine hükmen, ücret iadesiz.
--   * Kişi başı aynı anda en fazla 3 aktif lig. Lig adına küfür filtresi.
-- supabase_sema_v2 + faz2_2 + faz2_14 üzerine, idempotent.
-- ============================================================

-- ---------- 0. DEFTER TİPLERİ ----------
alter table defter drop constraint if exists defter_tip_check;
alter table defter add constraint defter_tip_check check (tip in
  ('baslangic','seri_giris','seri_odul','berabere_iade',
   'rake','reklam','paket','duzeltme','referans',
   'lig_giris','lig_odul','lig_iade'));

-- ---------- 1. TABLOLAR ----------

create table if not exists arkadas_ligleri (
  id          uuid primary key default gen_random_uuid(),
  kod         text not null unique,
  ad          text not null check (char_length(ad) between 3 and 24),
  kurucu      uuid not null references profiller(id),
  giris       integer not null check (giris = 0 or giris between 100 and 10000),
  boyut       integer not null check (boyut in (4, 6, 8)),
  sure_gun    integer not null check (sure_gun between 3 and 30),
  durum       text not null default 'acik'
              check (durum in ('acik','aktif','bitti','iptal')),
  havuz       integer not null default 0,
  kazanan     uuid references profiller(id),  -- tek şampiyon (bölüşümde null)
  kazananlar  jsonb,                          -- ödül alan uid listesi
  created_at  timestamptz not null default now(),
  baslama_at  timestamptz,
  bitis_at    timestamptz,
  finished_at timestamptz
);

create table if not exists alig_uyeler (
  lig_id      uuid not null references arkadas_ligleri(id) on delete cascade,
  user_id     uuid not null references profiller(id),
  puan        integer not null default 0,
  oynanan     integer not null default 0,
  g           integer not null default 0,
  b           integer not null default 0,
  m           integer not null default 0,
  hukmen      integer not null default 0,   -- KENDİ hükmen kayıpları (tie-break)
  aktif       boolean not null default true, -- false = ligi terk etti
  created_at  timestamptz not null default now(),
  primary key (lig_id, user_id)
);

create table if not exists alig_maclar (
  id          uuid primary key default gen_random_uuid(),
  lig_id      uuid not null references arkadas_ligleri(id) on delete cascade,
  tur         integer not null default 1,    -- fikstür haftası (gösterim)
  p1          uuid not null references profiller(id),
  p2          uuid not null references profiller(id),
  durum       text not null default 'bekliyor'
              check (durum in ('bekliyor','oyunda','bitti')),
  kazanan     uuid,                          -- null + bitti = berabere/iptal
  hukmen      boolean not null default false,
  katilimsiz  boolean not null default false, -- süre doldu, kimse gelmedi (0 puan)
  seri_id     uuid references seriler(id),
  hazir1_at   timestamptz,                   -- p1'in SON hazır sinyali
  hazir2_at   timestamptz,                   -- p2'nin SON hazır sinyali
  finished_at timestamptz,
  check (p1 <> p2),
  unique (lig_id, p1, p2)
);
create index if not exists alig_maclar_lig on alig_maclar (lig_id, durum);
create index if not exists alig_maclar_seri on alig_maclar (seri_id);

-- ---------- 2. KÜFÜR FİLTRESİ (admin panelden genişletilebilir) ----------
-- tur='token': normalize edilmiş KELİME birebir eşleşirse engel
--   (kısa kelimeler "klasik" gibi masum adları yakalamasın diye).
-- tur='icinde': boşluksuz normalize metinde GEÇERSE engel (uzun/nadir).
create table if not exists kufur_listesi (
  kelime text not null,
  tur    text not null default 'token' check (tur in ('token','icinde')),
  primary key (kelime, tur)
);
-- eski tek kolonlu pk'dan geçiş (idempotent):
do $$ begin
  if (select count(*) from information_schema.key_column_usage
       where table_name = 'kufur_listesi'
         and constraint_name = 'kufur_listesi_pkey') = 1 then
    alter table kufur_listesi drop constraint kufur_listesi_pkey;
    alter table kufur_listesi add primary key (kelime, tur);
  end if;
end $$;
-- token: kelime birebir · icinde: boşluksuz metinde geçerse
-- (DİKKAT: 'yarak' gibi kısa kökler icinde'ye GİREMEZ — "oynayarak"
--  masum adları yakalar; yalnız belirsizliği düşük uzun kökler girer.)
insert into kufur_listesi (kelime, tur) values
  ('amk','token'),('aq','token'),('oc','token'),('am','token'),
  ('sik','token'),('got','token'),('yarak','token'),('yarrak','token'),
  ('amcik','token'),('orospu','token'),('pic','token'),('ibne','token'),
  ('pezevenk','token'),('gavat','token'),('kahpe','token'),('kaltak','token'),
  ('surtuk','token'),('siktir','token'),('amina','token'),('fahise','token'),
  ('fuck','token'),('shit','token'),('bitch','token'),('whore','token'),
  ('cunt','token'),('dick','token'),('porn','token'),('penis','token'),
  ('sex','token'),
  ('amk','icinde'),('orospu','icinde'),('yarrak','icinde'),
  ('amcik','icinde'),('pezevenk','icinde'),('siktir','icinde'),
  ('sikerim','icinde'),('sikeyim','icinde'),('aminakoy','icinde'),
  ('gotveren','icinde'),('ibnelik','icinde')
on conflict (kelime, tur) do nothing;

-- Normalize: küçült, TR harfleri sadeleştir, leet rakamları harfe çevir.
create or replace function kufur_normalize(t text) returns text
language sql immutable as $$
  select translate(lower(coalesce(t, '')),
    'çğıöşü0134578@$', 'cgiosuoieastbas')
$$;

-- Ad uygun mu? (true = temiz)
create or replace function alig_ad_uygun(t text) returns boolean
language plpgsql stable as $$
declare n text; duz text; parca text; k record;
begin
  n := kufur_normalize(t);
  duz := regexp_replace(n, '[^a-z]', '', 'g');
  for k in select kelime, tur from kufur_listesi loop
    if k.tur = 'icinde' then
      if position(k.kelime in duz) > 0 then return false; end if;
    else
      foreach parca in array regexp_split_to_array(n, '[^a-z]+') loop
        if parca = k.kelime then return false; end if;
      end loop;
    end if;
  end loop;
  return true;
end $$;

-- ---------- 3. YARDIMCILAR ----------

-- Aynı anda en fazla 3 açık/aktif lig üyeliği.
create or replace function alig_aktif_sayim(u uuid) returns integer
language sql stable as $$
  select count(*)::integer from alig_uyeler lu
    join arkadas_ligleri l on l.id = lu.lig_id
   where lu.user_id = u and lu.aktif and l.durum in ('acik','aktif')
$$;

-- Tek devreli fikstür (dairesel yöntem): n çift sayı, n-1 hafta.
create or replace function alig_fikstur_cek(lid uuid)
returns void
language plpgsql as $$
declare uyeler uuid[]; n integer; hafta integer; i integer;
        a uuid; boyut integer; ev uuid; dep uuid;
begin
  select array_agg(user_id order by random()) into uyeler
    from alig_uyeler where lig_id = lid;
  n := array_length(uyeler, 1);
  for hafta in 1..(n - 1) loop
    for i in 1..(n / 2) loop
      ev  := uyeler[i];
      dep := uyeler[n + 1 - i];
      insert into alig_maclar (lig_id, tur, p1, p2)
        values (lid, hafta, least(ev, dep), greatest(ev, dep));
    end loop;
    -- dairesel döndürme: 1. sabit, kalanlar sağa kayar
    a := uyeler[n];
    for i in reverse n..3 loop
      uyeler[i] := uyeler[i - 1];
    end loop;
    uyeler[2] := a;
  end loop;
end $$;

-- ---------- 4. RPC'LER ----------

-- LİG KUR: ad filtreden geçer, ücret tahsil edilir, kurucu ilk üyedir.
create or replace function alig_olustur(ad_p text, giris_p integer,
                                       boyut_p integer, sure_p integer)
returns text
language plpgsql security definer set search_path = public as $$
declare k text; harfler text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
        i integer; lid uuid; bak integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  if ad_p is null or char_length(trim(ad_p)) not between 3 and 24 then
    raise exception 'lig adı 3-24 karakter olmalı';
  end if;
  if not alig_ad_uygun(ad_p) then
    raise exception 'lig adı uygunsuz ifade içeriyor';
  end if;
  if giris_p <> 0 and giris_p not between 100 and 10000 then
    raise exception 'katılım 0 ya da 100-10.000 Riva olmalı';
  end if;
  if boyut_p not in (4, 6, 8) then raise exception 'lig 4, 6 ya da 8 kişilik olabilir'; end if;
  if sure_p not between 3 and 30 then raise exception 'lig süresi 3-30 gün olmalı'; end if;
  if alig_aktif_sayim(auth.uid()) >= 3 then
    raise exception 'aynı anda en fazla 3 aktif ligde olabilirsin';
  end if;
  if giris_p > 0 then
    select bakiye into bak from cuzdanlar where user_id = auth.uid() for update;
    if bak < giris_p then raise exception 'yetersiz bakiye'; end if;
  end if;
  loop
    k := 'LIG-';
    for i in 1..4 loop
      k := k || substr(harfler, 1 + floor(random() * length(harfler))::int, 1);
    end loop;
    exit when not exists (select 1 from arkadas_ligleri where kod = k);
  end loop;
  insert into arkadas_ligleri (kod, ad, kurucu, giris, boyut, sure_gun, havuz)
    values (k, trim(ad_p), auth.uid(), giris_p, boyut_p, sure_p, giris_p)
    returning id into lid;
  insert into alig_uyeler (lig_id, user_id) values (lid, auth.uid());
  if giris_p > 0 then
    insert into defter (user_id, tip, miktar, aciklama)
      values (auth.uid(), 'lig_giris', -giris_p, k);
  end if;
  return k;
end $$;
grant execute on function alig_olustur(text, integer, integer, integer) to authenticated;

-- LİGE KATIL: kodla; lig dolunca OTOMATİK başlar + fikstür çekilir.
create or replace function alig_katil(k text) returns uuid
language plpgsql security definer set search_path = public as $$
declare l arkadas_ligleri; bak integer; sayi integer;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;
  select * into l from arkadas_ligleri where kod = upper(trim(k)) for update;
  if not found then raise exception 'lig bulunamadı'; end if;
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
grant execute on function alig_katil(text) to authenticated;

-- Puan işleme (iç): maç kapanışında iki üyenin satırlarını günceller.
create or replace function alig_puan_isle(mc alig_maclar) returns void
language plpgsql as $$
begin
  if mc.katilimsiz then return; end if; -- kimse gelmedi: puan yok
  if mc.kazanan is null then -- berabere
    update alig_uyeler set puan = puan + 1, oynanan = oynanan + 1, b = b + 1
      where lig_id = mc.lig_id and user_id in (mc.p1, mc.p2);
  else
    update alig_uyeler set puan = puan + 3, oynanan = oynanan + 1, g = g + 1
      where lig_id = mc.lig_id and user_id = mc.kazanan;
    update alig_uyeler set oynanan = oynanan + 1, m = m + 1,
        hukmen = hukmen + case when mc.hukmen then 1 else 0 end
      where lig_id = mc.lig_id
        and user_id = case when mc.kazanan = mc.p1 then mc.p2 else mc.p1 end;
  end if;
end $$;

-- LİG BİTİR (iç): şampiyonu belirle, %80 dağıt, %20 kasaya.
-- Eşitlik: ikili maç galibi → az hükmen → ödül eşit bölüşülür.
create or replace function alig_bitir(lid uuid) returns void
language plpgsql as $$
declare l arkadas_ligleri; enyuksek integer; adaylar uuid[]; h2h uuid;
        minh integer; odul integer; pay integer; kisi uuid;
        tek uuid; kalan integer;
begin
  select * into l from arkadas_ligleri where id = lid for update;
  if l.durum <> 'aktif' then return; end if;

  select max(puan) into enyuksek from alig_uyeler where lig_id = lid;
  select array_agg(user_id) into adaylar
    from alig_uyeler where lig_id = lid and puan = enyuksek;

  if array_length(adaylar, 1) = 2 then
    -- ikili averaj: aralarındaki maçın galibi (hükmen dahil)
    select kazanan into h2h from alig_maclar
      where lig_id = lid and durum = 'bitti'
        and least(p1, p2) = least(adaylar[1], adaylar[2])
        and greatest(p1, p2) = greatest(adaylar[1], adaylar[2]);
    if h2h is not null then adaylar := array[h2h]; end if;
  end if;
  if array_length(adaylar, 1) > 1 then
    -- az hükmen kaybı öne geçer
    select min(hukmen) into minh from alig_uyeler
      where lig_id = lid and user_id = any(adaylar);
    select array_agg(user_id) into adaylar from alig_uyeler
      where lig_id = lid and user_id = any(adaylar) and hukmen = minh;
  end if;

  tek := case when array_length(adaylar, 1) = 1 then adaylar[1] end;
  odul := floor(l.havuz * 0.8)::integer;
  pay := case when odul > 0 then odul / array_length(adaylar, 1) else 0 end;
  kalan := l.havuz;
  if pay > 0 then
    foreach kisi in array adaylar loop
      insert into defter (user_id, tip, miktar, aciklama)
        values (kisi, 'lig_odul', pay, l.kod);
      kalan := kalan - pay;
    end loop;
  end if;
  if kalan > 0 then
    insert into defter (user_id, tip, miktar, aciklama)
      values ('00000000-0000-0000-0000-000000000001', 'rake', kalan,
              'lig:' || l.kod);
  end if;
  update arkadas_ligleri set durum = 'bitti', kazanan = tek,
      kazananlar = to_jsonb(adaylar), finished_at = now()
    where id = lid;
end $$;

-- Tüm maçlar bittiyse ligi kapat (iç).
create or replace function alig_bitis_kontrol(lid uuid) returns void
language plpgsql as $$
begin
  if not exists (select 1 from alig_maclar
                  where lig_id = lid and durum <> 'bitti') then
    perform alig_bitir(lid);
  end if;
end $$;

-- HAZIRIM: 90 sn canlı sinyal. İki taraf da penceredeyse DOSTLUK SERİSİ
-- (bo1, rulet) açılır — Riva/Elo işlemez, sonuç tetikleyiciyle lige akar.
-- Dönüş: maçın güncel durumu (istemci yoklaması da bunu okur).
create or replace function alig_hazir(mid uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare mc alig_maclar; l arkadas_ligleri; sid uuid; benim1 boolean;
        diger_ts timestamptz;
begin
  select * into mc from alig_maclar where id = mid for update;
  if not found then raise exception 'maç bulunamadı'; end if;
  if auth.uid() not in (mc.p1, mc.p2) then raise exception 'bu maçta değilsin'; end if;
  select * into l from arkadas_ligleri where id = mc.lig_id;
  if l.durum <> 'aktif' then raise exception 'lig aktif değil'; end if;
  if mc.durum = 'bekliyor' then
    benim1 := auth.uid() = mc.p1;
    if benim1 then
      update alig_maclar set hazir1_at = now() where id = mid returning * into mc;
    else
      update alig_maclar set hazir2_at = now() where id = mid returning * into mc;
    end if;
    diger_ts := case when benim1 then mc.hazir2_at else mc.hazir1_at end;
    if diger_ts is not null and diger_ts > now() - interval '90 seconds' then
      sid := dostluk_seri(mc.p1, mc.p2, 'bo1', null, null);
      update alig_maclar set durum = 'oyunda', seri_id = sid
        where id = mid returning * into mc;
    end if;
  end if;
  return jsonb_build_object(
    'durum', mc.durum, 'seri_id', mc.seri_id,
    'hazir1_at', mc.hazir1_at, 'hazir2_at', mc.hazir2_at,
    'sunucu_now', now());
end $$;
grant execute on function alig_hazir(uuid) to authenticated;

-- LİGDEN AYRIL: açıkken tam iade (kurucu ayrılırsa lig iptal + herkese
-- iade); aktifken kalan maçlar rakiplere hükmen, ücret İADESİZ.
create or replace function alig_ayril(lid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare l arkadas_ligleri; mc alig_maclar; rakip uuid; uye alig_uyeler;
begin
  select * into l from arkadas_ligleri where id = lid for update;
  if not found then raise exception 'lig bulunamadı'; end if;
  select * into uye from alig_uyeler
    where lig_id = lid and user_id = auth.uid() and aktif;
  if not found then raise exception 'bu ligde değilsin'; end if;

  if l.durum = 'acik' then
    if l.kurucu = auth.uid() then
      perform alig_iptal(lid); -- kurucu açık ligi kapatırsa herkese iade
      return;
    end if;
    delete from alig_uyeler where lig_id = lid and user_id = auth.uid();
    if l.giris > 0 then
      insert into defter (user_id, tip, miktar, aciklama)
        values (auth.uid(), 'lig_iade', l.giris, l.kod);
      update arkadas_ligleri set havuz = havuz - l.giris where id = lid;
    end if;
    return;
  end if;
  if l.durum <> 'aktif' then raise exception 'lig kapanmış'; end if;

  update alig_uyeler set aktif = false
    where lig_id = lid and user_id = auth.uid();
  for mc in select * from alig_maclar
      where lig_id = lid and durum in ('bekliyor','oyunda')
        and auth.uid() in (p1, p2) for update loop
    rakip := case when mc.p1 = auth.uid() then mc.p2 else mc.p1 end;
    update alig_maclar set durum = 'bitti', kazanan = rakip, hukmen = true,
        finished_at = now() where id = mc.id returning * into mc;
    perform alig_puan_isle(mc);
  end loop;
  perform alig_bitis_kontrol(lid);
end $$;
grant execute on function alig_ayril(uuid) to authenticated;

-- LİG İPTAL (iç): herkese tam iade.
create or replace function alig_iptal(lid uuid) returns void
language plpgsql as $$
declare l arkadas_ligleri; u record;
begin
  select * into l from arkadas_ligleri where id = lid for update;
  if l.durum not in ('acik') then return; end if;
  if l.giris > 0 then
    for u in select user_id from alig_uyeler where lig_id = lid loop
      insert into defter (user_id, tip, miktar, aciklama)
        values (u.user_id, 'lig_iade', l.giris, l.kod);
    end loop;
  end if;
  update arkadas_ligleri set durum = 'iptal', havuz = 0, finished_at = now()
    where id = lid;
end $$;

-- ---------- 5. SERİ SONUCU → LİG PUANI (tetikleyici) ----------
create or replace function alig_seri_sonucu() returns trigger
language plpgsql security definer set search_path = public as $$
declare mc alig_maclar;
begin
  if new.durum = 'bitti' and old.durum <> 'bitti' then
    select * into mc from alig_maclar
      where seri_id = new.id and durum = 'oyunda' for update;
    if found then
      update alig_maclar set durum = 'bitti', kazanan = new.kazanan,
          finished_at = now() where id = mc.id returning * into mc;
      perform alig_puan_isle(mc);
      perform alig_bitis_kontrol(mc.lig_id);
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_alig_seri_sonucu on seriler;
create trigger trg_alig_seri_sonucu after update on seriler
  for each row execute function alig_seri_sonucu();

-- ---------- 6. ZAMAN KONTROLÜ (pg_cron 15 dk'da bir) ----------
-- a) 48 saatte dolmayan açık arkadas_ligleri → iptal + iade.
-- b) Süresi dolan aktif arkadas_ligleri → oynanmamış maçlar kurala göre kapanır,
--    lig biter, ödül dağılır.
create or replace function alig_zaman_kontrol() returns void
language plpgsql security definer set search_path = public as $$
declare l record; mc alig_maclar; kz uuid; hk boolean; ks boolean;
begin
  for l in select id from arkadas_ligleri
      where durum = 'acik' and created_at < now() - interval '48 hours' loop
    perform alig_iptal(l.id);
  end loop;

  for l in select id from arkadas_ligleri
      where durum = 'aktif' and bitis_at < now() for update loop
    for mc in select * from alig_maclar
        where lig_id = l.id and durum in ('bekliyor','oyunda') for update loop
      hk := false; ks := false; kz := null;
      if mc.durum = 'oyunda' then
        kz := null; -- maça girmişler ama seri sonuçlanmamış: berabere say
      elsif mc.hazir1_at is not null and mc.hazir2_at is null then
        kz := mc.p1; hk := true;   -- yalnız p1 niyet gösterdi: hükmen p1
      elsif mc.hazir2_at is not null and mc.hazir1_at is null then
        kz := mc.p2; hk := true;
      elsif mc.hazir1_at is null and mc.hazir2_at is null then
        ks := true;                 -- kimse gelmedi: maç iptal, puan yok
      end if;                       -- ikisi de işaretlemiş: berabere
      update alig_maclar set durum = 'bitti', kazanan = kz, hukmen = hk,
          katilimsiz = ks, finished_at = now()
        where id = mc.id returning * into mc;
      perform alig_puan_isle(mc);
    end loop;
    perform alig_bitir(l.id);
  end loop;
end $$;

-- pg_cron varsa 15 dakikada bir çalıştır (yoksa sessiz geç — Supabase'te
-- Dashboard > Database > Extensions'tan pg_cron açık olmalı).
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then null;
  end;
  begin
    perform cron.unschedule('golriva_alig_saat');
  exception when others then null;
  end;
  begin
    perform cron.schedule('golriva_alig_saat', '*/15 * * * *',
                          'select alig_zaman_kontrol()');
  exception when others then null;
  end;
end $$;

-- ---------- 7. OKUMA RPC'Sİ + RLS ----------

-- Üyesi olduğum arkadas_ligleri (özet).
create or replace function aliglerim()
returns table (id uuid, kod text, ad text, durum text, giris integer,
               boyut integer, uye_sayisi bigint, havuz integer,
               bitis_at timestamptz, kazanan uuid, benim_puan integer)
language sql security definer set search_path = public stable as $$
  select l.id, l.kod, l.ad, l.durum, l.giris, l.boyut,
         (select count(*) from alig_uyeler x where x.lig_id = l.id),
         l.havuz, l.bitis_at, l.kazanan, lu.puan
    from arkadas_ligleri l
    join alig_uyeler lu on lu.lig_id = l.id and lu.user_id = auth.uid()
   where lu.aktif or l.durum in ('bitti','iptal')
   order by (l.durum in ('acik','aktif')) desc, l.created_at desc
   limit 30
$$;
grant execute on function aliglerim() to authenticated;

alter table arkadas_ligleri       enable row level security;
alter table alig_uyeler   enable row level security;
alter table alig_maclar   enable row level security;
alter table kufur_listesi enable row level security;

do $$ begin
  create policy p_alig_oku on arkadas_ligleri for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy p_alig_uye_oku on alig_uyeler for select using (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy p_alig_mac_oku on alig_maclar for select
    using (exists (select 1 from alig_uyeler x
                    where x.lig_id = alig_maclar.lig_id
                      and x.user_id = auth.uid()));
exception when duplicate_object then null; end $$;
-- kufur_listesi: istemciye kapalı (politika yok) — yalnız sunucu okur.

-- İç fonksiyonlar istemciye kapalı.
revoke all on function alig_fikstur_cek(uuid) from public, anon, authenticated;
revoke all on function alig_puan_isle(alig_maclar) from public, anon, authenticated;
revoke all on function alig_bitir(uuid) from public, anon, authenticated;
revoke all on function alig_bitis_kontrol(uuid) from public, anon, authenticated;
revoke all on function alig_iptal(uuid) from public, anon, authenticated;
revoke all on function alig_zaman_kontrol() from public, anon, authenticated;
revoke all on function kufur_normalize(text) from public, anon;
revoke all on function alig_ad_uygun(text) from public, anon;
grant execute on function alig_ad_uygun(text) to authenticated; -- ön kontrol

notify pgrst, 'reload schema';
