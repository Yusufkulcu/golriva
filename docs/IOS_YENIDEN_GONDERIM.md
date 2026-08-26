# GolRiva — iOS yeniden gönderim (başka Mac'ten)

Bu belge, ana bilgisayara erişim yokken **ikinci bir Mac** ile App Store
incelemesine düzeltilmiş sürüm göndermek içindir. Paket: `golriva_proje_tam_v2.zip`.

## 0. Bu sürümde düzeltilenler (Apple reddi)
- **2.3.10 — başka platform adı:** Mağaza ekranındaki "Google Play / App Store",
  "(Google/Apple)" metinleri platforma göre seçiliyor; iOS'ta yalnız "App Store" görünür.
- **Uygulama içi satın alma:** StoreKit akışı artık uygulama açılışında dinleniyor
  (yarım kalan işlemler tamamlanıp sunucuya işleniyor), "Satın alımları geri yükle"
  butonu eklendi, ürün bulunamama nedeni admin'e ayrıntılı raporlanıyor.

## 1. App Store Connect tarafı — KODDAN ÖNCE kontrol et
Satın almanın incelemede çalışmamasının en yaygın sebebi kod değil, konsol ayarıdır:
1. **Sözleşmeler → Ücretli Uygulamalar (Paid Apps) sözleşmesi imzalı** olmalı
   (banka + vergi bilgileri tamam). İmzasızsa StoreKit ürün listesi BOŞ döner.
2. **Uygulama içi satın almalar:** `riva_500`, `riva_1500`, `riva_5000` — tür
   *Consumable*, her birinin en az bir yerelleştirmesi, fiyatı ve
   **inceleme ekran görüntüsü** olmalı; durum **"Ready to Submit"**.
3. Sürüm sayfasında **"In-App Purchases" bölümüne bu 3 ürünü EKLE** — ilk
   gönderimde ürünler uygulamayla birlikte incelenir; eklenmezse inceleme
   cihazında ürünler bulunamaz ve "satın alma çalışmıyor" reddi gelir.
4. Sandbox test hesabı (Users and Access → Sandbox) oluşturup kendi
   cihazında bir kez satın alma dene.

## 2. Mac kurulumu (1 kez, ~1 saat)
1. App Store'dan **Xcode** kur, aç, ek bileşenleri yüklet. Terminal:
   `sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -license accept`
2. **Flutter**: https://docs.flutter.dev/get-started/install/macos → zip'i aç,
   `export PATH="$PATH:$HOME/flutter/bin"` (zsh için ~/.zshrc'ye ekle).
   `flutter doctor` — Xcode ✓ ve CocoaPods ✓ olmalı. CocoaPods yoksa:
   `sudo gem install cocoapods` (ya da `brew install cocoapods`).
3. Xcode → Settings → Accounts → Apple ID'ni (geliştirici hesabı) ekle.

## 3. Projeyi aç ve derle
```bash
unzip golriva_proje_tam_v2.zip && cd golriva_full
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```
Xcode'da: Runner hedefi → **Signing & Capabilities** → Team'i seç,
"Automatically manage signing" açık. Bundle ID zaten projede kayıtlı;
Xcode yeni Mac için sertifika/profil üretir (eski Mac'teki sertifikaya
gerek yok — "Apple Distribution" için en fazla 2-3 sertifika açılabilir,
gerekirse Developer portalda eskisini iptal et).

**Sürüm numarasını yükselt:** `pubspec.yaml` → `version: X.Y.Z+N` — hem sürüm
hem build (+N) App Store'daki son gönderimden BÜYÜK olmalı.

Derleme (Supabase anahtarları --dart-define ile verilir; değerler
Supabase paneli → Settings → API'de):
```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://XXXX.supabase.co \
  --dart-define=SUPABASE_KEY=sb_publishable_...
```
Çıktı: `build/ios/ipa/*.ipa`

## 4. Yükle
- Xcode → Window → Organizer → Archives → **Distribute App → App Store Connect**
  (ya da Mac App Store'dan **Transporter** uygulamasıyla .ipa'yı sürükle).
- App Store Connect → sürüm → yeni build'i seç → "İnceleme notları"na şunu yaz:

> Düzeltmeler: (1) Uygulama içi satın alma akışı gözden geçirildi; ürünler bu
> sürüme eklendi ve sandbox'ta doğrulandı. (2) Diğer platformlara atıf yapan
> tüm metinler kaldırıldı. Test için sandbox hesabı: <e-posta / şifre>.
> Satın alma: Mağaza sekmesi → Riva paketi → satın al; Riva anında cüzdana işlenir.

- Resolution Center'daki ret mesajına da kısa bir "düzeltildi, yeni build
  gönderildi" yanıtı yaz — bazen aynı inceleyici hızlı bakar.

## 5. Sık takılanlar
- `pod install` hata verirse: `cd ios && pod repo update && pod install`.
- "No profiles for com.xxx": Xcode → Signing'de Team seçili mi; Apple ID'nin
  o takımda Admin/App Manager yetkisi var mı.
- Build yüklendi ama sürümde görünmüyor: 5-15 dk "Processing" sürer; e-posta gelir.
- Satın alma sandbox'ta "ürün bulunamadı": 1. bölümdeki 3 maddeyi tekrar kontrol et
  (en sık: ürün sürüme eklenmemiş ya da Paid Apps sözleşmesi imzasız).
