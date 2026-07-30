# GOLRIVA — Supabase Kurulumu (Faz 2)

Bu rehber çevrimiçi altyapıyı (hesap + RIVA cüzdanı + ranked eşleştirme)
ayağa kaldırır. Uygulama Supabase YAPILANDIRILMADAN da tamamen çalışır
(hot-seat) — testler ve CI hiçbir zaman ağa çıkmaz.

## 1. Proje oluştur

1. https://supabase.com → ücretsiz hesap → **New project**
   - İsim: `golriva` · Region: **Frankfurt (eu-central-1)** (TR'ye en yakın)
   - Database şifresini bir yere kaydet.
2. Proje açılınca **Project Settings → API Keys**'den iki değeri kopyala:
   - `Project URL` (https://xxxx.supabase.co)
   - **Publishable key** (`sb_publishable_...`) — yeni projelerde görünen anahtar budur.
     (Eski projelerde "Legacy API Keys" sekmesindeki `anon public` da çalışır.)
   - ⚠️ **Secret key / service_role**'e DOKUNMA — o yalnızca yerel admin paneli için.

## 2. Şemayı kur (SQL Editor)

**SQL Editor → New query** ile şu dosyaları SIRAYLA çalıştır
(bu reponun `supabase/` klasöründen; her biri "Success" demeli):

1. `supabase_sema_v2.sql` — tablolar, RLS, ekonomi, seri/rulet RPC'leri
2. `admin_ek.sql` — yasaklar, veri itirazları, özet görünümler
3. `lig_ek.sql` — 7 kademeli lig sistemi
4. `faz2_ek.sql` — kuyruktan çıkış + istemci eşleşme RPC'si
5. `faz2_2_ek.sql` — ÇEVRİMİÇİ OYNANIŞ: hamle senkronu + maç sonucu RPC'leri (YENİ)

## 3. Misafir girişini aç

**Authentication → Sign In / Up → Anonymous sign-ins → Enable**
(Misafir hesap modeli: kullanıcı e-posta vermeden oynar, 500 RIVA ile başlar.)

## 4. Uygulamayı bağla

Anahtarlar koda gömülmez, derlerken verilir:

```bash
cd ~/Desktop/futgame-flutter
flutter run --dart-define=SUPABASE_URL=https://XXXX.supabase.co \
            --dart-define=SUPABASE_KEY=sb_publishable_...
```

(Eski tip `anon` JWT anahtarın varsa `--dart-define=SUPABASE_ANON_KEY=eyJ...`
olarak vermeye devam edebilirsin — ikisi de kabul edilir.)

APK için:

```bash
flutter build apk --debug \
  --dart-define=SUPABASE_URL=https://XXXX.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```

## 5. Dene

1. Uygulamayı aç → lobinin üstünde **"Çevrimiçi maçlar için hesap aç · +500 RIVA"** şeridi görünür.
2. Kullanıcı adı seç → hesap açılır, şeritte adın + **500 RIVA** + Elo 1000 görünür.
3. **RANKED** → masa (çaylak/klasik/yüksek/elit) + mod (tek maç / Bo3) seç → **KUYRUĞA GİR**.
4. İkinci bir cihazda (ya da ikinci emülatörde) ikinci hesapla aynı masaya gir →
   birkaç saniyede **RAKİP BULUNDU**: seri açılır, iki taraftan giriş RIVA'sı düşer,
   ruletin seçtiği oyun ikinize de gösterilir.

5. **RAKİP BULUNDU → MAÇA BAŞLA**: maç iki cihazda eşzamanlı oynanır —
   sıra sende değilken yazamazsın, hamleler 1-2 saniyede karşıya geçer,
   maç bitince sonuç sunucuda işlenir (ödül RIVA + Elo + lig puanı).
   Bo3'te "SONRAKİ MAÇ" ile seri devam eder; bayrak direği simgesi = çekilme.

> Not: Faz 2.2 rulet havuzu sıra tabanlı 8 oyundur; Bayrak Yarışı ve
> Kariyer İkizi çevrimiçi havuza Faz 2.3'te girer (hot-seat'te oynanmaya
> devam ederler). Test verisi temizliği: SQL Editor'dan
> `truncate seriler, maclar, defter, eslestirme_kuyrugu cascade;` ile sıfırlanabilir
> (profiller kalır) — ya da kullanıcıyı silip yeniden kayıt olunur.

## Güvenlik ilkeleri (değişmez)

- İstemcide yalnızca **publishable/anon** anahtar; tüm yazma işlemleri SECURITY DEFINER RPC'lerden.
- `service_role` anahtarı yalnızca YEREL admin panelinde; asla repoya/uygulamaya girmez.
- Cüzdan tek gerçek kaynaktan beslenir: `defter` + trigger. İstemci bakiye YAZAMAZ.
- Elo ve lig satın alınamaz; rulet sunucuda döner, istemci oyun seçemez.
