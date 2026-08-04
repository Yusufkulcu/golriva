-- ============================================================
-- GOLRIVA FAZ 2.12 — İSTATİSTİK GÖRÜNÜMLERİ (admin paneli)
-- Sunucu tarafı toplama (aggregation). Yalnız service_role okur.
-- Supabase SQL editöründe çalıştır.
-- ============================================================

-- ── GENEL TOPLAMLAR (tek satır) ──────────────────────────────
create or replace view v_ist_genel as
select
  (select count(*) from profiller)                                          as toplam_uye,
  (select count(*) from profiller where created_at >= date_trunc('day',now())) as bugun_uye,
  (select count(*) from seriler)                                            as toplam_seri,
  (select count(*) from seriler where dostluk)                             as dostluk_seri,
  (select count(*) from maclar)                                            as toplam_mac,
  (select count(*) from maclar where durum = 'oyunda')                     as aktif_oyun,
  (select count(*) from seriler where durum = 'oyunda')                    as aktif_seri,
  (select count(*) from eslestirme_kuyrugu)                                as kuyrukta,
  coalesce((select sum(bakiye) from cuzdanlar),0)                          as riva_dolasim,
  (select count(*) from satin_almalar)                                     as satin_adet,
  coalesce((select sum(miktar) from satin_almalar),0)                      as satin_riva,
  (select count(*) from reklam_odulleri)                                   as reklam_odul_adet,
  coalesce((select sum(miktar) from reklam_odulleri),0)                    as reklam_odul_riva,
  (select count(*) from reklam_gosterimleri)                              as reklam_gecis_adet,
  coalesce((select sum(miktar) from defter where tip='rake'),0)            as kasa_rake,
  (select count(*) from cihaz_tokenleri where platform='android')          as cihaz_android,
  (select count(*) from cihaz_tokenleri where platform='ios')              as cihaz_ios;

-- ── GÜNLÜK KIRILIM (son 30 gün) ──────────────────────────────
create or replace view v_ist_gunluk as
select
  d::date                                                                  as gun,
  (select count(*) from profiller p where p.created_at::date = d::date)     as yeni_uye,
  (select count(*) from seriler s  where s.created_at::date = d::date)      as seri,
  (select count(*) from maclar  m  where m.created_at::date = d::date)      as mac,
  (select count(*) from reklam_odulleri r where r.created_at::date = d::date) as reklam_odul,
  (select count(*) from reklam_gosterimleri g where g.created_at::date = d::date) as reklam_gecis,
  (select count(*) from satin_almalar a where a.created_at::date = d::date) as satin_adet,
  coalesce((select sum(miktar) from satin_almalar a where a.created_at::date = d::date),0) as satin_riva,
  coalesce((select sum(miktar) from defter df where df.tip='rake' and df.created_at::date = d::date),0) as rake
from generate_series(current_date - interval '29 day', current_date, interval '1 day') d
order by gun;

-- ── OYUN MODU DAĞILIMI (hangi oyun ne kadar oynanmış) ────────
create or replace view v_ist_oyun as
select oyun_kodu, count(*)::int as adet
from maclar
group by oyun_kodu
order by adet desc;

-- ── SAAT YOĞUNLUĞU (son 7 gün, 0-23 saat) ────────────────────
-- "En yoğun saat" — gerçek eşzamanlı zirve için değil, hacim dağılımı için.
create or replace view v_ist_saat as
select
  g.s                                                                      as saat,
  coalesce(count(m.id),0)::int                                             as adet
from generate_series(0,23) g(s)
left join maclar m
  on extract(hour from m.created_at)::int = g.s
  and m.created_at >= now() - interval '7 day'
group by g.s
order by g.s;

-- ── PAKET DAĞILIMI (mağazadan hangi paket kaç kez) ───────────
create or replace view v_ist_paket as
select urun, count(*)::int as adet, coalesce(sum(miktar),0)::int as toplam_riva
from satin_almalar
group by urun
order by adet desc;

-- ── ERİŞİM: yalnız admin (service_role) ──────────────────────
do $$
declare v text;
begin
  foreach v in array array['v_ist_genel','v_ist_gunluk','v_ist_oyun','v_ist_saat','v_ist_paket'] loop
    execute format('revoke all on %I from anon, authenticated', v);
    execute format('grant select on %I to service_role', v);
  end loop;
end $$;

notify pgrst, 'reload schema';
