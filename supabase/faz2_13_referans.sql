-- ============================================================
-- GOLRIVA FAZ 2.13 — REFERANS KODLARI (reklam kampanya takibi)
-- Amaç: reklam verilen her kanal için ayrı kod; kayıt sırasında
-- isteğe bağlı girilir, nereden kaç kullanıcı geldiği ölçülür,
-- koda tanımlı Riva hediyesi kayıt bonusuna eklenir.
-- supabase_sema_v2 üzerine, idempotent — SQL Editor'de çalıştır.
-- ============================================================

-- ---------- 1. TABLOLAR ----------

create table if not exists referans_kodlari (
  kod         text primary key check (kod ~ '^[A-Z0-9_]{3,20}$'),
  aciklama    text,                              -- kanal notu: "Kick yayını", "Instagram Ağustos"
  riva        integer not null default 0 check (riva between 0 and 100000),
  aktif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists referans_kullanimlari (
  id          bigint generated always as identity primary key,
  kod         text not null references referans_kodlari(kod),
  user_id     uuid not null references profiller(id) on delete cascade,
  miktar      integer not null default 0,        -- kullanım ANINDAKİ ödül (kod sonradan değişse de rapor doğru kalır)
  created_at  timestamptz not null default now(),
  unique (user_id)                               -- kullanıcı başına tek referans
);
create index if not exists referans_kullanim_kod on referans_kullanimlari (kod, created_at);

-- ---------- 2. DEFTER TİPİNE 'referans' EKLE ----------
-- (şemadaki isimsiz inline check'in otomatik adı: defter_tip_check)

alter table defter drop constraint if exists defter_tip_check;
alter table defter add constraint defter_tip_check check (tip in
  ('baslangic','seri_giris','seri_odul','berabere_iade',
   'rake','reklam','paket','duzeltme','referans'));

-- ---------- 3. RPC: referans_kullan (istemci, kayıt sırasında) ----------
-- Kurallar: giriş şart · kod aktif olmalı · kullanıcı başına 1 kez ·
-- yalnız taze profil (kayıttan sonraki 1 saat) — kod sonradan duyulursa
-- ekonomi delinmesin. Ödül defter üzerinden işler (tetikleyici bakiyeyi günceller).

create or replace function referans_kullan(p_kod text) returns integer
language plpgsql security definer set search_path = public as $$
declare k referans_kodlari; profil_yasi interval;
begin
  if auth.uid() is null then raise exception 'giriş gerekli'; end if;

  select * into k from referans_kodlari
    where kod = upper(trim(coalesce(p_kod,''))) and aktif;
  if not found then raise exception 'geçersiz ya da pasif referans kodu'; end if;

  select now() - created_at into profil_yasi from profiller where id = auth.uid();
  if profil_yasi is null then raise exception 'önce profil oluşturulmalı'; end if;
  if profil_yasi > interval '1 hour' then
    raise exception 'referans kodu yalnız kayıt sırasında kullanılabilir';
  end if;

  begin
    insert into referans_kullanimlari (kod, user_id, miktar)
      values (k.kod, auth.uid(), k.riva);
  exception when unique_violation then
    raise exception 'referans kodu zaten kullanılmış';
  end;

  if k.riva > 0 then
    insert into defter (user_id, tip, miktar, aciklama)
      values (auth.uid(), 'referans', k.riva, 'referans: ' || k.kod);
  end if;
  return k.riva;
end $$;

revoke all on function referans_kullan(text) from public, anon;
grant execute on function referans_kullan(text) to authenticated;

-- ---------- 4. RLS ----------
-- referans_kodlari: istemciye politika YOK — kod listesi taranamaz
-- (RPC security definer; panel service_role ile RLS'i zaten aşar).
-- referans_kullanimlari: kullanıcı yalnız kendi kaydını görebilir.

alter table referans_kodlari      enable row level security;
alter table referans_kullanimlari enable row level security;
do $$ begin
  create policy p_referans_kullanim_oku on referans_kullanimlari
    for select using (user_id = auth.uid());
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
