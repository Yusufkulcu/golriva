/// REKLAM KİMLİK SABİTLERİ — kimlikler BURAYA BİR KEZ girilir.
///
/// GÜVENLİK NOTU: AdMob birim kimlikleri GİZLİ DEĞİLDİR — derlenmiş
/// uygulamadan zaten okunabilirler; koda yazmak risk oluşturmaz.
/// (Gizli olan şeyler — service_role anahtarı vb. — buraya ASLA yazılmaz.)
///
/// ÇÖZÜMLEME SIRASI (her birim için):
///   1) --dart-define verildiyse O kazanır (CI/özel derleme için),
///   2) yoksa buradaki sabit,
///   3) sabit de boşsa Google'ın RESMİ TEST kimliği (geliştirme güvenli).
///
/// DİKKAT: AndroidManifest.xml ve Info.plist'teki UYGULAMA kimlikleri
/// (App ID) ayrı — onlar native dosyalarda kalır.
class ReklamSabitleri {
  // ── BURAYA KENDİ BİRİM KİMLİKLERİNİ YAZ ──────────────────────────
  // Örnek: 'ca-app-pub-1234567890123456/1234567890'
  static const odulluAndroid = ''; // Ödüllü reklam · Android
  static const odulluIos = ''; //     Ödüllü reklam · iOS
  // ─────────────────────────────────────────────────────────────────

  // Google resmi TEST kimlikleri (ödüllü):
  static const _testOdulluAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testOdulluIos = 'ca-app-pub-3940256099942544/1712485313';

  static const _defineAndroid = String.fromEnvironment('REKLAM_ODUL_ANDROID');
  static const _defineIos = String.fromEnvironment('REKLAM_ODUL_IOS');

  static String get odulluAndroidBirim => _defineAndroid.isNotEmpty
      ? _defineAndroid
      : (odulluAndroid.isNotEmpty ? odulluAndroid : _testOdulluAndroid);

  static String get odulluIosBirim => _defineIos.isNotEmpty
      ? _defineIos
      : (odulluIos.isNotEmpty ? odulluIos : _testOdulluIos);
}
