-- ============================================================================
-- FUTBOL ZEKÂ OYUNLARI — Supabase Şeması v2 (Seri sistemi + Random oyun)
-- 28 Temmuz 2026 · v1'in üzerine iki tasarım kararı (kullanıcı onaylı):
--   A) RANKED = TEK KUYRUK + RASTGELE OYUN: oyuncu oyun SEÇEMEZ, sunucu seçer.
--      Dostluk maçında seçim serbest (ekonomisiz, Elo'suz).
--   B) SERİLER (Bo1/Bo3): ekonomi ve Elo'nun birimi MAÇ değil SERİDİR.
--      Bo3 = 2 kazanan alır; berabere oyun sayılmaz, yeni random oyunla devam;
--      emniyet: 5 oyunda bitmezse skor üstün olan kazanır, eşitse seri berabere.
-- İlkeler v1 ile aynı: sunucu otoriter, defter tek gerçek, istemci salt-okur.
-- ============================================================================

-- ---------- 1. PROFİL & CÜZDAN & DEFTER (v1 ile aynı çekirdek) ----------

create table if not exists profiller (
  id          uuid primary key references auth.users(id) on delete cascade,
  kullanici_adi text not null unique check (char_length(kullanici_adi) between 3 and 14),
  elo         integer not null default 1000,
  created_at  timestamptz not null default now()
);

create table if not exists cuzdanlar (
  user_id     uuid primary key references profiller(id) on delete cascade,
  bakiye      integer not null default 0 check (bakiye >= 0),
  updated_at  timestamptz not null default now()
);

-- KASA (rake hesabı): '00000000-0000-0000-0000-000000000001'

create table if not exists defter (
  id          bigint generated always as identity primary key,
  user_id     uuid not null,
  tip         text not null check (tip in
               ('baslangic','seri_giris','seri_odul','berabere_iade',
                'rake','reklam','paket','duzeltme')),
  miktar      integer not null,
  seri_id     uuid,                             -- ekonomi seri bazında işler
  aciklama    text,
  created_at  timestamptz not null default now()
);
create index if not exists defter_user_gun on defter (user_id, tip, created_at);

create or replace function defter_uygula() returns trigger
language plpgsql as $$
begin
  if new.user_id <> '00000000-0000-0000-0000-000000000001' then
    update cuzdanlar set bakiye = bakiye + new.miktar, updated_at = now()
      where user_id = new.user_id;
    if not found then raise exception 'cüzdan yok: %', new.user_id; end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_defter_uygula on defter;
create trigger trg_defter_uygula after insert on defter
  for each row execute function defter_uygula();

-- ---------- 2. OYUNLAR & MASALAR ----------

-- Random havuz DB'den yönetilir: bir oyunu havuzdan çekmek = tek UPDATE.
create table if not exists oyunlar (
  kod          text primary key,
  ad           text not null,
  random_havuz boolean not null default true    -- ranked rulete girer mi
);
insert into oyunlar (kod, ad) values
  ('kupa_drafti','Kupa Draftı'), ('bonservis_avi','Bonservis Avı'),
  ('sari_kart_avi','Sarı Kart Avı'), ('mac_rekortmenleri','Maç Rekortmenleri'),
  ('milli_gol_krallari','Milli Gol Kralları'), ('kariyer_ikizi','Kariyer İkizi'),
  ('en_kisa_kadro','En Kısa Kadro'), ('bayrak_yarisi','Bayrak Yarışı'),
  ('en_genc_kadro','En Genç Kadro'), ('hedefi_tuttur','Hedefi Tuttur')
on conflict (kod) do nothing;

-- Bo1 ve Bo3 sütunları ayrı: tüm değerler TAMSAYI, %15 rake korunur.
-- Bo3 girişleri Bo1'in ~2,4-2,5 katı; berabere_net = ceil(rake/2) (negatif).
create table if not exists masalar (
  kod              text primary key,
  giris            integer not null,   -- Bo1
  kazanan_net      integer not null,
  berabere_net     integer not null,
  giris_bo3        integer not null,
  kazanan_net_bo3  integer not null,
  berabere_net_bo3 integer not null,
  min_bakiye_kilit integer not null default 0,
  aktif            boolean not null default true
);
insert into masalar values
  ('caylak',  50,  35,  -8,  120,  84, -18,    0, true),
  ('klasik', 100,  70, -15,  250, 175, -38,    0, true),
  ('yuksek', 250, 175, -38,  600, 420, -90,  500, true),
  ('elit',   500, 350, -75, 1200, 840, -180, 1000, true)
on conflict (kod) do update set
  giris=excluded.giris, kazanan_net=excluded.kazanan_net, berabere_net=excluded.berabere_net,
  giris_bo3=excluded.giris_bo3, kazanan_net_bo3=excluded.kazanan_net_bo3,
  berabere_net_bo3=excluded.berabere_net_bo3, min_bakiye_kilit=excluded.min_bakiye_kilit;

-- ---------- 3. SERİLER & MAÇLAR ----------

create table if not exists seriler (
  id          uuid primary key default gen_random_uuid(),
  mod         text not null check (mod in ('bo1','bo3')),
  masa_kod    text not null references masalar(kod),
  dostluk     boolean not null default false,   -- true: ekonomisiz + Elo'suz + oyun seçilebilir
  sabit_oyun  text references oyunlar(kod),     -- dostlukta seçilen oyun (null=random)
  p1          uuid not null references profiller(id),
  p2          uuid not null references profiller(id),
  skor1       integer not null default 0,
  skor2       integer not null default 0,
  oyun_sayisi integer not null default 0,       -- oynanan oyun (berabere dahil) — emniyet 5
  durum       text not null default 'oyunda' check (durum in ('oyunda','bitti','iptal')),
  kazanan     uuid,                              -- null + bitti => seri berabere
  created_at  timestamptz not null default now(),
  finished_at timestamptz,
  check (p1 <> p2),
  check (kazanan is null or kazanan in (p1, p2))
);

create table if not exists maclar (
  id          uuid primary key default gen_random_uuid(),
  seri_id     uuid not null references seriler(id) on delete cascade,
  seri_sira   integer not null,                 -- serinin kaçıncı oyunu
  oyun_kodu   text not null references oyunlar(kod),
  durum       text not null default 'oyunda' check (durum in ('oyunda','bitti')),
  kazanan     uuid,                              -- null + bitti => oyun berabere (sayılmaz)
  seed        bigint not null default (floor(random()*9e15))::bigint,
  sunucu_durumu jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  finished_at timestamptz,
  unique (seri_id, seri_sira)
);

create table if not exists hamleler (
  id          bigint generated always as identity primary key,
  mac_id      uuid not null references maclar(id) on delete cascade,
  user_id     uuid not null references profiller(id),
  hamle_no    integer not null,
  icerik      jsonb not null,
  sunucu_ts   timestamptz not null default now(),
  unique (mac_id, user_id, hamle_no)
);

-- TEK kuyruk: oyun kodu YOK (ranked'da oyun sunucu seçer) — sadece mod + masa.
create table if not exists eslestirme_kuyrugu (
  user_id     uuid primary key references profiller(id) on delete cascade,
  mod         text not null check (mod in ('bo1','bo3')),
  masa_kod    text not null references masalar(kod),
  elo         integer not null,
  created_at  timestamptz not null default now()
);

create table if not exists reklam_odulleri (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references profiller(id) on delete cascade,
  ag          text not null default 'admob',
  ssv_islem_id text not null,
  miktar      integer not null default 50,
  created_at  timestamptz not null default now(),
  unique (ag, ssv_islem_id)
);

-- ---------- 4. YARDIMCI FONKSİYONLAR ----------

create or replace function rastgele_oyun() returns text
language sql as $$
  select kod from oyunlar where random_havuz order by random() limit 1
$$;

create or replace function seri_hedef(m text) returns integer
language sql immutable as $$ select case when m = 'bo3' then 2 else 1 end $$;

create or replace function masa_giris(m masalar, md text) returns integer
language sql immutable as $$ select case when md='bo3' then m.giris_bo3 else m.giris end $$;

-- ---------- 5. RPC'LER ----------

create or replace function yeni_kullanici(u uuid, ad text) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into profiller (id, kullanici_adi) values (u, ad);
  insert into cuzdanlar (user_id, bakiye) values (u, 0);
  insert into defter (user_id, tip, miktar, aciklama)
    values (u, 'baslangic', 500, 'hoş geldin birimi');
end $$;

-- Ranked kuyruk: SADECE mod + masa. Oyun istemcinin bileceği iş değil.
create or replace function kuyruga_gir(md text, masa text) returns void
language plpgsql security definer set search_path = public as $$
declare m masalar; b integer; e integer; gerekli integer;
begin
  if md not in ('bo1','bo3') then raise exception 'geçersiz mod'; end if;
  select * into m from masalar where kod = masa and aktif;
  if not found then raise exception 'masa yok'; end if;
  gerekli := masa_giris(m, md);
  select bakiye into b from cuzdanlar where user_id = auth.uid() for update;
  if b < gerekli then raise exception 'yetersiz bakiye'; end if;
  if b < m.min_bakiye_kilit then raise exception 'masa kilitli'; end if;
  select elo into e from profiller where id = auth.uid();
  insert into eslestirme_kuyrugu (user_id, mod, masa_kod, elo)
    values (auth.uid(), md, masa, e)
  on conflict (user_id) do update
    set mod = excluded.mod, masa_kod = excluded.masa_kod, created_at = now();
end $$;

-- Eşleştirici (service_role): iki oyuncudan seri girişini atomik alır,
-- seriyi + İLK oyunu (RASTGELE) açar. Oyuncular oyunu ancak bu an öğrenir.
create or replace function seri_eslesti(a uuid, b uuid, md text, masa text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare m masalar; sid uuid; ba integer; bb integer; gerekli integer;
begin
  select * into m from masalar where kod = masa;
  gerekli := masa_giris(m, md);
  select bakiye into ba from cuzdanlar where user_id = a for update;
  select bakiye into bb from cuzdanlar where user_id = b for update;
  if ba < gerekli or bb < gerekli then raise exception 'yetersiz bakiye'; end if;
  insert into seriler (mod, masa_kod, p1, p2) values (md, masa, a, b)
    returning id into sid;
  insert into defter (user_id, tip, miktar, seri_id) values
    (a, 'seri_giris', -gerekli, sid),
    (b, 'seri_giris', -gerekli, sid);
  insert into maclar (seri_id, seri_sira, oyun_kodu)
    values (sid, 1, rastgele_oyun());
  delete from eslestirme_kuyrugu where user_id in (a, b);
  return sid;
end $$;

-- Dostluk serisi: ekonomi YOK, Elo YOK, oyun SEÇİLEBİLİR (null = yine random).
create or replace function dostluk_seri(a uuid, b uuid, md text, oyun text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare sid uuid;
begin
  if oyun is not null and not exists (select 1 from oyunlar where kod = oyun) then
    raise exception 'oyun yok';
  end if;
  insert into seriler (mod, masa_kod, dostluk, sabit_oyun, p1, p2)
    values (md, 'caylak', true, oyun, a, b) returning id into sid;
  insert into maclar (seri_id, seri_sira, oyun_kodu)
    values (sid, 1, coalesce(oyun, rastgele_oyun()));
  return sid;
end $$;

-- Seri kapanışı (iç fonksiyon): ödül + rake + Elo — SERİ BAŞINA BİR KEZ.
create or replace function seri_kapat(sid uuid, kazanan_p uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s seriler; m masalar; g integer; net integer; bnet integer; rake integer;
        e1 integer; e2 integer; beklenen numeric; k integer := 32; kaybeden uuid;
begin
  select * into s from seriler where id = sid for update;
  select * into m from masalar where kod = s.masa_kod;
  if not s.dostluk then
    g := masa_giris(m, s.mod);
    if s.mod = 'bo3' then net := m.kazanan_net_bo3; bnet := m.berabere_net_bo3;
    else net := m.kazanan_net; bnet := m.berabere_net; end if;
    if kazanan_p is null then
      insert into defter (user_id, tip, miktar, seri_id) values
        (s.p1, 'berabere_iade', g + bnet, sid),
        (s.p2, 'berabere_iade', g + bnet, sid);
      rake := -2 * bnet;
    else
      insert into defter (user_id, tip, miktar, seri_id)
        values (kazanan_p, 'seri_odul', g + net, sid);
      rake := 2 * g - (g + net);
    end if;
    insert into defter (user_id, tip, miktar, seri_id, aciklama)
      values ('00000000-0000-0000-0000-000000000001', 'rake', rake, sid, s.masa_kod || '/' || s.mod);
    if kazanan_p is not null then
      kaybeden := case when kazanan_p = s.p1 then s.p2 else s.p1 end;
      select elo into e1 from profiller where id = kazanan_p;
      select elo into e2 from profiller where id = kaybeden;
      beklenen := 1.0 / (1.0 + power(10.0, (e2 - e1) / 400.0));
      update profiller set elo = elo + round(k * (1 - beklenen)) where id = kazanan_p;
      update profiller set elo = greatest(100, elo - round(k * (1 - beklenen))) where id = kaybeden;
    end if;
  end if;
  update seriler set durum = 'bitti', kazanan = kazanan_p, finished_at = now()
    where id = sid;
end $$;

-- Oyun sonucu (oyun motoru edge function'ı çağırır):
--   kazanan_p null = oyun berabere -> SAYILMAZ, yeni random oyun açılır.
--   Skor hedefe ulaşınca ya da 5 oyun emniyetine çarpınca seri kapanır.
create or replace function mac_sonuc(mid uuid, kazanan_p uuid) returns void
language plpgsql security definer set search_path = public as $$
declare mc maclar; s seriler; hedef integer; yeni_oyun text;
begin
  select * into mc from maclar where id = mid and durum = 'oyunda' for update;
  if not found then raise exception 'maç uygun durumda değil'; end if;
  select * into s from seriler where id = mc.seri_id for update;
  if s.durum <> 'oyunda' then raise exception 'seri kapalı'; end if;
  if kazanan_p is not null and kazanan_p not in (s.p1, s.p2) then
    raise exception 'kazanan seride değil';
  end if;

  update maclar set durum = 'bitti', kazanan = kazanan_p, finished_at = now() where id = mid;
  update seriler set
      oyun_sayisi = oyun_sayisi + 1,
      skor1 = skor1 + case when kazanan_p = p1 then 1 else 0 end,
      skor2 = skor2 + case when kazanan_p = p2 then 1 else 0 end
    where id = s.id
    returning * into s;

  hedef := seri_hedef(s.mod);
  if s.skor1 >= hedef then perform seri_kapat(s.id, s.p1);
  elsif s.skor2 >= hedef then perform seri_kapat(s.id, s.p2);
  elsif s.oyun_sayisi >= 5 then
    -- emniyet: skor üstünlüğü, eşitse seri berabere
    if s.skor1 > s.skor2 then perform seri_kapat(s.id, s.p1);
    elsif s.skor2 > s.skor1 then perform seri_kapat(s.id, s.p2);
    else perform seri_kapat(s.id, null); end if;
  else
    -- seri devam: dostlukta sabit oyun varsa o, yoksa yeni random
    yeni_oyun := coalesce(s.sabit_oyun, rastgele_oyun());
    insert into maclar (seri_id, seri_sira, oyun_kodu)
      values (s.id, s.oyun_sayisi + 1, yeni_oyun);
  end if;
end $$;

-- Reklam ödülü: v1 ile aynı (SSV + günlük 10 tavan)
create or replace function reklam_odul_ver(u uuid, ag_adi text, islem_id text)
returns integer
language plpgsql security definer set search_path = public as $$
declare bugun integer; odul integer := 50; tavan integer := 10;
begin
  select count(*) into bugun from reklam_odulleri
    where user_id = u and created_at >= date_trunc('day', now());
  if bugun >= tavan then raise exception 'günlük reklam tavanı doldu'; end if;
  insert into reklam_odulleri (user_id, ag, ssv_islem_id, miktar)
    values (u, ag_adi, islem_id, odul);
  insert into defter (user_id, tip, miktar, aciklama)
    values (u, 'reklam', odul, ag_adi || ':' || islem_id);
  return odul;
end $$;

-- ---------- 6. RLS ----------

alter table profiller          enable row level security;
alter table cuzdanlar          enable row level security;
alter table defter             enable row level security;
alter table oyunlar            enable row level security;
alter table masalar            enable row level security;
alter table seriler            enable row level security;
alter table maclar             enable row level security;
alter table hamleler           enable row level security;
alter table eslestirme_kuyrugu enable row level security;
alter table reklam_odulleri    enable row level security;

create policy p_profil_oku on profiller for select using (true);
create policy p_cuzdan_oku on cuzdanlar for select using (user_id = auth.uid());
create policy p_defter_oku on defter    for select using (user_id = auth.uid());
create policy p_oyun_oku   on oyunlar   for select using (true);
create policy p_masa_oku   on masalar   for select using (true);
create policy p_seri_oku   on seriler   for select using (auth.uid() in (p1, p2));
create policy p_mac_oku    on maclar    for select
  using (exists (select 1 from seriler sx where sx.id = seri_id and auth.uid() in (sx.p1, sx.p2)));
create policy p_hamle_oku  on hamleler  for select
  using (exists (select 1 from maclar mx join seriler sx on sx.id = mx.seri_id
                 where mx.id = mac_id and auth.uid() in (sx.p1, sx.p2)));
create policy p_kuyruk_oku on eslestirme_kuyrugu for select using (user_id = auth.uid());
create policy p_reklam_oku on reklam_odulleri    for select using (user_id = auth.uid());

-- ---------- 7. NOTLAR ----------
-- * Ranked'da oyuncu OYUN SEÇEMEZ; oyun kodu seriye maç açılırken yazılır ve
--   istemciye maç başlarken bildirilir ("rulet" animasyonu için ideal an).
-- * Bo3'te her oyun YENİ random'dur (berabere tekrarı dahil) — plan yapılamaz.
-- * Elo ve birim SERİ başına bir kez işlenir; dostluk serilerinde ikisi de yok.
-- * random_havuz sütunuyla bir oyun ruletten anında çekilebir (örn. Bayrak
--   Yarışı gecikme şikayeti gelirse) — uygulama güncellemesi gerekmez.
-- * v1'deki tüm sunucu-otoriter ilkeler geçerli (SSV, sunucu_ts, kör değerler).
