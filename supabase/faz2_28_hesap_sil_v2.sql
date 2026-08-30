-- ============================================================
-- GOLRIVA FAZ 2.28 — HESAP SİLME v2 (Arkadaş Ligi sonrası)
-- SORUN: faz2_10'daki hesabimi_sil, faz2_19 lig tablolarını bilmiyor →
--   arkadas_ligleri_kurucu_fkey / alig_* 23503 hataları. Admin panel ise
--   fonksiyonu değil doğrudan profiller.delete() çağırıyordu → seriler
--   engeli. (Apple/Google kuralı: hesap silme ÇALIŞMAK zorunda.)
-- ÇÖZÜM:
--   * hesap_sil_ic(u) — TEK kapsamlı temizlik (panel service_role ile
--     çağırır; hesabimi_sil de bunu kullanır)
--   * Lig kuralları: kurduğu AÇIK lig iptal + herkese iade; üyesi olduğu
--     açık ligden iade ile çıkar; aktif/bitmiş liglerde maç+üyelik
--     kayıtları silinir (lig kalanlarla sürer); kuruculuk başka üyeye
--     devredilir, hiç üye kalmadıysa lig silinir.
-- faz2_10 + faz2_19 üzerine, idempotent.
-- ============================================================

create or replace function hesap_sil_ic(u uuid) returns void
language plpgsql security definer set search_path = public as $$
declare devralan uuid; l record;
begin
  if u is null then raise exception 'kullanıcı yok'; end if;

  -- 1) davetler (seri_id cascade değil; hedefli davetler dahil)
  delete from davetler
    where kurucu = u or hedef = u
       or seri_id in (select id from seriler where p1 = u or p2 = u);

  -- 2) seriler (cascade: maclar → hamleler/bayrak_kaplar; seri ödülleri)
  delete from hamleler where user_id = u;
  delete from seri_reklam_odulleri where user_id = u;
  delete from seriler where p1 = u or p2 = u;

  -- 3) ARKADAŞ LİGLERİ
  -- 3a) kurduğu AÇIK ligler: iptal (herkese iade — alig_iptal)
  for l in select id from arkadas_ligleri
            where kurucu = u and durum = 'acik' loop
    perform alig_iptal(l.id);
  end loop;
  -- 3b) üyesi olduğu AÇIK ligler: havuzdan düş + üyelikten çık
  --     (girişin iadesi anlamsız — cüzdan zaten siliniyor)
  for l in select al.id, al.giris from arkadas_ligleri al
             join alig_uyeler au on au.lig_id = al.id and au.user_id = u
            where al.durum = 'acik' and al.kurucu <> u loop
    if l.giris > 0 then
      update arkadas_ligleri set havuz = havuz - l.giris where id = l.id;
    end if;
    delete from alig_uyeler where lig_id = l.id and user_id = u;
  end loop;
  -- 3c) aktif/bitmiş liglerdeki izler: maç + üyelik satırları silinir,
  --     şampiyonluk kaydı anonimleşir (lig kalan üyelerle yaşar)
  delete from alig_maclar where p1 = u or p2 = u;
  delete from alig_uyeler where user_id = u;
  update arkadas_ligleri set kazanan = null where kazanan = u;
  -- 3d) hâlâ kurucusu göründüğü ligler: başka üyeye devret; üye yoksa sil
  for l in select id from arkadas_ligleri where kurucu = u loop
    select user_id into devralan
      from alig_uyeler where lig_id = l.id limit 1;
    if devralan is null then
      delete from alig_maclar where lig_id = l.id;
      delete from arkadas_ligleri where id = l.id;
    else
      update arkadas_ligleri set kurucu = devralan where id = l.id;
    end if;
  end loop;

  -- 4) kalan kişisel kayıtlar (cascade olmayanlar açıkça)
  delete from lig_gecmisi where user_id = u;
  delete from reklam_odulleri where user_id = u;
  delete from reklam_gosterimleri where user_id = u;
  delete from defter where user_id = u;

  -- 5) profil (cascade: cüzdan/arkadaşlar/istekler/engel/şikayet/kuyruk/
  --    satın alma/itiraz/referans…) + auth kullanıcısı (cihaz jetonları)
  delete from profiller where id = u;
  delete from auth.users where id = u;
end $$;
revoke all on function hesap_sil_ic(uuid) from public, anon, authenticated;
grant execute on function hesap_sil_ic(uuid) to service_role;

-- Kullanıcının kendi hesabını silmesi — v2: ortak temizliği kullanır.
create or replace function hesabimi_sil() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'oturum yok'; end if;
  perform hesap_sil_ic(auth.uid());
end $$;
grant execute on function hesabimi_sil() to authenticated, anon;

notify pgrst, 'reload schema';
