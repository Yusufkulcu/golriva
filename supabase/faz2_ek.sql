-- =============================================================
-- GOLRIVA FAZ 2 EK — istemci eslesme RPC'leri (30 Tem 2026)
-- supabase_sema_v2.sql + admin_ek.sql + lig_ek.sql SONRASINDA calistir.
-- =============================================================

-- Kuyruktan cikis (istemci kendi kaydini silebilsin — RLS delete yerine RPC)
create or replace function kuyruktan_cik() returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from eslestirme_kuyrugu where user_id = auth.uid();
end $$;

-- ESLESME DENEMESI (istemci tetikler, mantik tamamen SUNUCUDA):
-- kuyruktaki kaydimla ayni mod+masa'da bekleyen EN ESKI uygun rakibi bul,
-- atomik olarak seri ac (seri_eslesti). Cifte eslesmeye karsi:
-- for update skip locked. Donus: seri id ya da null (bekle).
create or replace function eslesme_dene() returns uuid
language plpgsql security definer set search_path = public as $$
declare ben eslestirme_kuyrugu; rakip eslestirme_kuyrugu; sid uuid;
begin
  select * into ben from eslestirme_kuyrugu
    where user_id = auth.uid() for update skip locked;
  if not found then return null; end if;
  select * into rakip from eslestirme_kuyrugu
    where user_id <> ben.user_id
      and mod = ben.mod and masa_kod = ben.masa_kod
      and abs(elo - ben.elo) <= 250
    order by created_at
    limit 1 for update skip locked;
  if not found then return null; end if;
  -- eski bekleyen p1 olur (adalet: once gelen once yazilir)
  if rakip.created_at <= ben.created_at then
    sid := seri_eslesti(rakip.user_id, ben.user_id, ben.mod, ben.masa_kod);
  else
    sid := seri_eslesti(ben.user_id, rakip.user_id, ben.mod, ben.masa_kod);
  end if;
  return sid;
end $$;

revoke all on function kuyruktan_cik() from public;
revoke all on function eslesme_dene() from public;
grant execute on function kuyruktan_cik() to authenticated;
grant execute on function eslesme_dene() to authenticated;
