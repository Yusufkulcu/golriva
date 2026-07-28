# GOLRIVA Flutter — Faz 1 İskeleti
*28 Temmuz 2026 · İlk teslim: tema + veri boru hattı + En Kısa Kadro (draft şablonu) + testler*

## Mac'te ilk çalıştırma (5 dakika)
```bash
cd futgame-flutter
flutter create . --platforms=android,ios,web --project-name golriva   # platform klasörlerini üretir (bir kez)
flutter pub get
flutter test          # motor + normalizasyon testleri (23 senaryo)
flutter run           # bağlı telefon/simülatör/Chrome'da açar
```
Not: `flutter create .` mevcut lib/, test/, assets/, pubspec'e DOKUNMAZ; yalnız
android/, ios/, web/ platform klasörlerini ekler.

## Bu teslimde ne var
- `lib/theme/golriva_theme.dart` — koyu premium tema (renkler, Big Shoulders Display /
  Space Grotesk / Figtree — google_fonts ile).
- `lib/data/players_repository.dart` + `assets/data/boy_data.json` — 13.166 oyuncu,
  29 kulüp, 6 lig (HTML oyunlardaki boy_data.js'in JSON'u).
- `lib/games/core/tr_norm.dart` — Türkçe-duyarsız arama (İ/ı kuralları + aksan tablosu).
- `lib/games/en_kisa_kadro/engine.dart` — SAF DART motor (UI'sız, tam test edilebilir):
  6 tur kulüp/lig ruleti, 1K-2D-2O-1F, kap-kaç, sebepli engeller, +210 boş slot cezası,
  öncelik değişimi, min-3-harf arama. UI'a güvenmez, her seçimi kendisi doğrular
  (online geçişte sunucu motoruna birebir taşınacak mantık budur).
- `lib/games/en_kisa_kadro/screen.dart` — draft şablonu ekranı (hot-seat).
- `lib/screens/lobby.dart` — GOLRIVA lobisi; 10 oyun kartı (1 aktif, 9 "yakında").
- `test/` — çapa testleri (Messi 170, CR7 188, Alex-Fenerbahçe...), motor kuralları,
  20 tohumlu tam oyun simülasyonu.
- `.github/workflows/ci.yml` — push'ta otomatik: analiz + test + web build + APK artifact.

## Otomasyon düzeni (önemli)
Claude'un bulut ortamı Google'ın Dart/Flutter depolarına kapalı → derleme/test orada
KOŞMAZ. Düzen şu: Claude kodu + testleri yazar → sen `git push` → GitHub Actions
her şeyi koşar ve APK üretir → telefona kur. Mac'te `flutter test` ile de anında koşabilirsin.

## Sıradaki adımlar (Faz 1 devamı)
1. Kalan 4 şablon: kör av, refleks, soru, serbest kadro → 10 oyunun tamamı.
2. Beyin-Top SVG işareti + vektör ikon seti asset olarak.
3. Kademeli skor açılışı animasyonu (kör oyunlarda) + reveal animasyonları.
4. Faz 2: Supabase (auth/misafir, rulet eşleştirme, Riva, lig) — şema hazır.
