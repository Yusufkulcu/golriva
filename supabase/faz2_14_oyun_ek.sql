-- ============================================================
-- GOLRIVA FAZ 2.14 — OYUN AKIŞI EKLERİ (lansman geri bildirimi)
--   A) BO3'te aynı oyun tekrar gelmez (seride oynanmışlar dışlanır)
--   B) Dostluk BO3: davette 3 oyun seçilebilir (oyun listesi)
--   C) Bayrak Yarışı + Kariyer İkizi çevrimiçi havuza girer;
--      Bayrak için sunucu hakemli "KAP" yarışı (ilk yazan kazanır)
--   D) Arkadaşa doğrudan davet (hedefli davet + gelen davet listesi)
-- supabase_sema_v2 + faz2_4 + faz2_2 üzerine, idempotent.
-- ============================================================

-- ---------- A. SERİDE OYUN TEKRARI YOK ----------
-- Havuzdan, bu seride DAHA ÖNCE AÇILMIŞ oyunları dışlayarak seç;
-- havuz tükenirse (teorik) tekrar serbest.
create or replace function rastgele_oyun_seri(sid uuid) returns text
language sql as $$
  select coalesce(
    (select kod from oyunlar
      where random_havuz
        and kod not in (select oyun_kodu from maclar where seri_id = sid)
      order by random() limit 1),
    (select kod from oyunlar where random_havuz order by random() limit 1)
  )
$$;

-- ---------- B. DOSTLUKTA OYUN LİSTESİ ----------
alter table seriler  add column if not exists oyun_listesi jsonb;
alter table davetler add column if not exists oyunlar jsonb;
alter table davetler add column if not exists hedef uuid references profiller(id);

-- dostluk_seri v2: tek oyun YA DA sıralı oyun listesi (bo3'te 3 seçim).
-- Liste verilirse ilk maç listenin ilk oyunu olur; sonrakiler mac_sonuc'ta.
-- Eski 4 parametreli sürüm DÜŞÜRÜLÜR — çift imza belirsizliği olmasın.
drop function if exists dostluk_seri(uuid, uuid, text, text);
create or replace function dostluk_seri(a uuid, b uuid, md text, oyun text,
                                        liste jsonb default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare sid uuid; ilk text; e jsonb;
begin
  if oyun is not null and not exists (select 1 from oyunlar where kod = oyun) then
    raise exception 'oyun yok';
  end if;
  if liste is not null then
    if jsonb_typeof(liste) <> 'array' or jsonb_array_length(liste) not between 1 and 5 then
      raise exception 'geçersiz oyun listesi';
    end if;
    for e in select * from jsonb_array_elements(liste) loop
      if not exists (select 1 from oyunlar where kod = (e #>> '{}')) then
        raise exception 'oyun yok: %', (e #>> '{}');
      end if;
    end loop;
    ilk := liste ->> 0;
  end if;
  insert into seriler (mod, masa_kod, dostluk, sabit_oyun, oyun_listesi, p1, p2)
    values (md, 'caylak', true, oyun, liste, a, b) returning id into sid;
  insert into maclar (seri_id, seri_sira, oyun_kodu)
    values (sid, 1, coalesce(ilk, oyun, rastgele_oyun()));
  return sid;
end $$;
revoke all on function dostluk_seri(uuid, uuid, text, text, jsonb) from public, anon, authenticated;

-- mac_sonuc v3: seri devamında yeni oyun seçimi —
--   1) dostluk sabit oyun → hep o;
--   2) dostluk oyun listesi → sıradaki (liste biterse tekrarsız rastgele);
--   3) ranked → TEKRARSIZ rastgele (A maddesi).
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
    if s.skor1 > s.skor2 then perform seri_kapat(s.id, s.p1);
    elsif s.skor2 > s.skor1 then perform seri_kapat(s.id, s.p2);
    else perform seri_kapat(s.id, null); end if;
  else
    yeni_oyun := coalesce(
      s.sabit_oyun,
      case when s.oyun_listesi is not null
             and jsonb_array_length(s.oyun_listesi) > s.oyun_sayisi
           then s.oyun_listesi ->> s.oyun_sayisi end,
      rastgele_oyun_seri(s.id));
    insert into maclar (seri_id, seri_sira, oyun_kodu)
      values (s.id, s.oyun_sayisi + 1, yeni_oyun);
  end if;
end $$;

-- ---------- C. BAYRAK + KARİYER HAVUZA GİRER ----------
update oyunlar set random_havuz = true
 where kod in ('bayrak_yarisi', 'kariyer_ikizi');

-- BAYRAK "KAP" HAKEMİ: tur başına TEK kayıt — kim önce yazarsa yarış onun.
-- bos=true kaydı "süre doldu, kimse kapmadı" kararıdır; o da yarışa girer
-- (son milisaniyede kapan gerçek oyuncu, sonradan gelen bos kararını yener
--  çünkü satır zaten yazılmıştır — İLK KAYIT KAZANIR, sunucu tek hakem).
create table if not exists bayrak_kaplar (
  mac_id      uuid not null references maclar(id) on delete cascade,
  tur         integer not null,
  user_id     uuid,                       -- null = bos karar
  bos         boolean not null default false,
  created_at  timestamptz not null default now(),
  primary key (mac_id, tur)
);
alter table bayrak_kaplar enable row level security;

create or replace function bayrak_kap(mid uuid, tur_no integer, bos_mu boolean)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare mc maclar; kayit bayrak_kaplar;
begin
  select mx.* into mc from maclar mx
    join seriler sx on sx.id = mx.seri_id
    where mx.id = mid and mx.durum = 'oyunda'
      and (auth.uid() = sx.p1 or auth.uid() = sx.p2);
  if not found then raise exception 'maç uygun değil ya da katılımcı değilsin'; end if;
  begin
    insert into bayrak_kaplar (mac_id, tur, user_id, bos)
      values (mid, tur_no, case when bos_mu then null else auth.uid() end, bos_mu);
  exception when unique_violation then null;
  end;
  select * into kayit from bayrak_kaplar where mac_id = mid and tur = tur_no;
  return jsonb_build_object('sahip', kayit.user_id, 'bos', kayit.bos);
end $$;
revoke all on function bayrak_kap(uuid, integer, boolean) from public, anon;
grant execute on function bayrak_kap(uuid, integer, boolean) to authenticated;

-- ---------- D. HEDEFLİ DAVET (arkadaşa doğrudan maç isteği) ----------
do $$ begin
  create policy p_davet_hedef_oku on davetler for select using (hedef = auth.uid());
exception when duplicate_object then null; end $$;

-- davet_olustur2: oyun listesi + isteğe bağlı hedef arkadaş.
--   oyunlar: null = rulet · ["kod"] = tek oyun · bo3'te 3 kod = maç sırası.
--   hedef_ad: verilirse yalnız o kullanıcı arkadaşsa kurulur ve onun
--   "gelen davetler" listesine düşer (kodla katılım da çalışmaya devam eder).
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
grant execute on function davet_olustur2(text, jsonb, text) to authenticated;

-- davet_katil v2: oyun listesi dostluk serisine taşınır.
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
  sid := dostluk_seri(d.kurucu, auth.uid(), d.mod, d.oyun_kodu, d.oyunlar);
  update davetler set durum = 'eslesti', seri_id = sid where kod = d.kod;
  return sid;
end $$;

-- Bana gelen bekleyen davetler (arkadaşlar/oyna ekranı yoklar).
create or replace function gelen_davetler()
returns table (kod text, kurucu_ad text, mod text, oyunlar jsonb,
               created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select d.kod, p.kullanici_adi, d.mod, d.oyunlar, d.created_at
  from davetler d join profiller p on p.id = d.kurucu
  where d.hedef = auth.uid() and d.durum = 'bekliyor'
    and d.created_at > now() - interval '30 minutes'
  order by d.created_at desc
$$;
grant execute on function gelen_davetler() to authenticated;

notify pgrst, 'reload schema';
