# GOLRIVA — LANSMAN KILAVUZU
*Market (Play/App Store), AdMob ve yayın öncesi yapılacakların tam listesi.*
*Kod tarafı hazır — bu belgedeki adımların hepsi hesap/panel işi, senin yapman gerekiyor.*

---

## 1) ADMOB (reklam geliri)

Şu an uygulama Google'ın **TEST reklamlarını** gösteriyor (gelir yok). Gerçeğe geçiş:

1. **admob.google.com** → Google hesabınla AdMob hesabı aç → ödeme bilgilerini gir
   (vergi bilgisi + banka hesabı; TR'de bireysel hesap olur).
2. **Uygulama ekle** (Android için bir, iOS için bir): başta "mağazada yayında değil"
   seçebilirsin, yayınlanınca mağaza kaydıyla eşlersin.
3. Her uygulamada **Reklam birimi → Ödüllü (Rewarded)** oluştur.
4. Eline 4 kimlik geçer — ikisi UYGULAMA, ikisi BİRİM kimliği:
   - Android **uygulama** kimliği → `android/app/src/main/AndroidManifest.xml`
     içindeki `com.google.android.gms.ads.APPLICATION_ID` değerini değiştir
     (şu an `ca-app-pub-3940256099942544~3347511713` = test).
   - iOS **uygulama** kimliği → `ios/Runner/Info.plist` → `GADApplicationIdentifier`.
   - **Birim** kimlikleri derlerken verilir (koda gömmeye gerek yok):
     ```
     flutter build ... \
       --dart-define=REKLAM_ODUL_ANDROID=ca-app-pub-XXXX/YYYY \
       --dart-define=REKLAM_ODUL_IOS=ca-app-pub-XXXX/ZZZZ
     ```
5. Geliştirirken kendi tıklamalarınla hesabı riske atmamak için test cihazı ekle
   (AdMob → Ayarlar → Test cihazları) ya da test kimlikleriyle derlemeye devam et.
6. Yayın sonrası: alan adın olursa `app-ads.txt` ekle (AdMob panel söylüyor).

> Sunucu tarafı hazır: ödül +50, günlük 10 tavan, çift ödül engeli. Gerçek SSV
> (AdMob sunucu imza doğrulaması) Faz 3'te eklenecek — o zamana dek kurallar
> sunucudaki tavanlarla korunuyor.

---

## 2) GOOGLE PLAY (Android yayın + uygulama içi satın alma)

1. **play.google.com/console** → Geliştirici hesabı aç (25$ bir kerelik).
2. **Uygulama oluştur** → paket adı önemli: `android/app/build.gradle.kts` içindeki
   `applicationId` şu an muhtemelen `com.example...` — yayından ÖNCE kendi adına
   çevirmemiz gerekiyor (ör. `com.golriva.app`). **Bunu bana söyle, kodda ben değiştireyim**
   (sonradan değiştirilemez!).
3. **İmzalama anahtarı** (release derlemeler için şart — şu an debug imzalı):
   ```bash
   keytool -genkey -v -keystore ~/golriva-anahtar.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias golriva
   ```
   Çıkan `.jks` dosyasını ve şifreyi YEDEKLE (kaybedersen güncelleme yayınlayamazsın).
   Sonra bana "keystore hazır" de — `key.properties` + gradle imzalama ayarını ben eklerim.
4. **Uygulama içi ürünler**: Console → Para kazanma → Uygulama içi ürünler →
   ürünleri **aynen şu kimliklerle** oluştur (admin panel MARKET sekmesindeki kodlarla
   birebir aynı olmalı): `riva_500`, `riva_1500`, `riva_5000` — tür: **Tüketilebilir
   değil, "Uygulama içi ürün"** (Play'de tüketim uygulama tarafında yönetilir, bizim
   akış bunu yapıyor). Fiyatları belirle, etkinleştir.
   - Yeni paket eklemek istersen: önce admin panel MARKET'ten ekle, sonra Play'de
     aynı kodla ürünü aç. Kod değişikliği gerekmez.
5. **Test**: Kapalı test kanalına (Internal testing) `flutter build appbundle` ile
   `.aab` yükle → test kullanıcısı olarak kendini ekle → satın almayı gerçek para
   ödemeden test edebilirsin (lisanslı test kullanıcıları).
6. **Veri güvenliği formu**: e-posta (hesap), fotoğraf (avatar), cihaz kimliği
   (reklam) topladığını beyan et. Gizlilik politikası URL'si ister — tek sayfalık
   bir metin gerekir (istersen ben hazırlarım).
7. Mağaza kaydı: simge (hazır), ekran görüntüleri (telefondan alırsın),
   kısa/uzun açıklama (istersen ben yazarım).

---

## 3) APP STORE (iOS yayın + uygulama içi satın alma)

1. **developer.apple.com** → Apple Developer Program (99$/yıl).
2. Xcode'da Runner hedefinde **Bundle Identifier**'ı kendi adına çevir
   (Play'dekiyle uyumlu olsun: ör. `com.golriva.app`) ve Team seç.
3. **App Store Connect** → yeni uygulama → aynı bundle id.
4. **In-App Purchases** → tür: **Consumable** → aynı kimlikler:
   `riva_500`, `riva_1500`, `riva_5000` (+ panelden eklediklerin).
5. **TestFlight** ile test: `flutter build ipa` → yükle → kendine dağıt.
   IAP sandbox test hesabı: App Store Connect → Users → Sandbox Testers.
6. App Privacy formu: e-posta, fotoğraf, cihaz kimliği (reklam).
7. Not: Xcode'un eskiyse önce güncelle — o zaman `pubspec.yaml`'daki
   `device_info_plus: 12.3.0` sabitlemesini kaldırırız (bana söyle, ben yaparım).

---

## 4) SUPABASE (sunucu) — SON DURUM KONTROLÜ

SQL Editor'de sırayla çalıştırılmış olmalı (hepsi güvenle tekrarlanabilir):
`supabase_sema_v2` → `admin_ek` → `lig_ek` → `faz2_ek` → `faz2_2_ek` →
`faz2_3_kuyruk_tazelik` → `faz2_3b_sunucu_saati` → `faz2_4_ek` →
`faz2_5_reklam` → `admin_v2_yetki` → `faz2_6_hesap` → `faz2_7_market`

Ayrıca panelden:
- Authentication → Email → **Confirm email** tercihen KAPALI (açıksa kayıt,
  e-posta onayı ister; uygulama bunu da yönetiyor)
- Authentication → Emails → Reset Password şablonunda `{{ .Token }}` olmalı
- Ücretsiz plandaysan: proje 1 hafta hareketsiz kalınca uyur — yayına yakın
  Pro plana geçmek gerekir (uyuma yok + günlük yedek).

---

## 5) YAYIN ÖNCESİ SON LİSTE

- [ ] applicationId / bundle id değişimi (bana söyle — koddan ben yapayım)
- [ ] Android keystore + imzalama (anahtarı sen üret, bağlamayı ben yapayım)
- [ ] AdMob gerçek kimlikler (Manifest + Info.plist + dart-define)
- [ ] Play + App Store ürünleri (riva_*) tanımlı ve etkin
- [ ] Gizlilik politikası sayfası (istersen ben yazarım)
- [ ] Supabase Pro + tüm SQL'ler uygulanmış
- [ ] admin_v2_yetki.sql çalıştırıldı (güvenlik!) ve panel yalnız senin bilgisayarında
- [ ] Gerçek cihazlarda uçtan uca test: kayıt → maç → reklam → satın alma (sandbox)
- [ ] "GOLRIVA" isim/telif ön kontrolü (marka taraması)

*Faz 3 (yayın sonrası): mağaza makbuz doğrulaması + AdMob SSV, sunucu taraflı
oyun motorları (hile direnci), gerçek zamanlı kanal, push bildirim.*
