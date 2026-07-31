-- ============================================================
-- GOLRIVA ADMIN v2 — YETKİ SIKILAŞTIRMA + PANEL FONKSİYONLARI
-- admin_ek + lig_ek + faz2_5 üzerine uygulanır (idempotent).
-- Panel YALNIZ yerelde, service_role anahtarıyla çalışır.
-- ============================================================

-- ---------- 1. GÜVENLİK DELİĞİ KAPAMA (kritik!) ----------
-- admin_* ve sezon_sifirla bugüne dek PUBLIC çağrılabilirdi:
-- kötü niyetli istemci kendine Riva basabilir / rakibini yasaklayabilirdi.
revoke all on function admin_duzeltme(uuid, integer, text) from public, anon, authenticated;
revoke all on function admin_yasak(uuid, boolean, text)    from public, anon, authenticated;
revoke all on function sezon_sifirla(text)                 from public, anon, authenticated;

-- ---------- 2. PANELİN İHTİYACI OLAN YETKİLER (yalnız service_role) ----------
grant execute on function admin_duzeltme(uuid, integer, text) to service_role;
grant execute on function admin_yasak(uuid, boolean, text)    to service_role;
grant execute on function sezon_sifirla(text)                 to service_role;
-- hükmen kapatma: mac_sonuc iç fonksiyonu (katılımcı şartı yok — panel yetkisi)
grant execute on function mac_sonuc(uuid, uuid)               to service_role;
grant execute on function davet_temizle()                     to service_role;

-- ---------- 3. SERİ İPTAL + İADE (atomik, iz bırakır) ----------
-- Açık bir seriyi iptal eder; ranked ise iki oyuncuya girişleri defterden
-- iade eder (tetikleyici bakiyeleri günceller). Dostlukta iade yoktur.
create or replace function admin_seri_iptal(sid uuid, neden text) returns void
language plpgsql security definer set search_path = public as $$
declare s seriler; m masalar; g integer;
begin
  if neden is null or char_length(neden) < 5 then raise exception 'neden zorunlu'; end if;
  select * into s from seriler where id = sid for update;
  if not found then raise exception 'seri yok'; end if;
  if s.durum <> 'oyunda' then raise exception 'seri zaten kapalı'; end if;
  update maclar set durum = 'bitti', finished_at = now()
    where seri_id = sid and durum = 'oyunda';
  update seriler set durum = 'iptal', finished_at = now() where id = sid;
  if not s.dostluk then
    select * into m from masalar where kod = s.masa_kod;
    g := masa_giris(m, s.mod);
    insert into defter (user_id, tip, miktar, seri_id, aciklama) values
      (s.p1, 'duzeltme', g, sid, 'ADMIN seri iptal iadesi: ' || neden),
      (s.p2, 'duzeltme', g, sid, 'ADMIN seri iptal iadesi: ' || neden);
  end if;
end $$;
revoke all on function admin_seri_iptal(uuid, text) from public, anon, authenticated;
grant execute on function admin_seri_iptal(uuid, text) to service_role;

notify pgrst, 'reload schema';
