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
  static const odulluAndroid = 'ca-app-pub-2345769438522527/1165661406'; // Ödüllü reklam · Android
  static const odulluIos = 'ca-app-pub-2345769438522527/3816141400'; //     Ödüllü reklam · iOS
  // FAZ 2.25 — GEÇİŞ (interstitial) reklamı: maç sonunda ödüllü
  // izlenmediyse %50 ihtimalle. AdMob'da "Geçiş reklamı" türünde birim aç,
  // kimlikleri buraya yaz (boş kalırsa Google TEST kimliği kullanılır).
  static const gecisAndroid = 'ca-app-pub-2345769438522527/1671544974'; // Geçiş reklamı · Android
  static const gecisIos = 'ca-app-pub-2345769438522527/2517722783'; //     Geçiş reklamı · iOS
  // ─────────────────────────────────────────────────────────────────

  // Google resmi TEST kimlikleri (ödüllü):
  static const _testOdulluAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testOdulluIos = 'ca-app-pub-3940256099942544/1712485313';
  // Google resmi TEST kimlikleri (geçiş):
  static const _testGecisAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testGecisIos = 'ca-app-pub-3940256099942544/4411468910';

  static const _defineAndroid = String.fromEnvironment('REKLAM_ODUL_ANDROID');
  static const _defineIos = String.fromEnvironment('REKLAM_ODUL_IOS');
  static const _defineGecisAndroid =
      String.fromEnvironment('REKLAM_GECIS_ANDROID');
  static const _defineGecisIos = String.fromEnvironment('REKLAM_GECIS_IOS');

  static String get gecisAndroidBirim => _defineGecisAndroid.isNotEmpty
      ? _defineGecisAndroid
      : (gecisAndroid.isNotEmpty ? gecisAndroid : _testGecisAndroid);

  static String get gecisIosBirim => _defineGecisIos.isNotEmpty
      ? _defineGecisIos
      : (gecisIos.isNotEmpty ? gecisIos : _testGecisIos);

  static String get odulluAndroidBirim => _defineAndroid.isNotEmpty
      ? _defineAndroid
      : (odulluAndroid.isNotEmpty ? odulluAndroid : _testOdulluAndroid);

  static String get odulluIosBirim => _defineIos.isNotEmpty
      ? _defineIos
      : (odulluIos.isNotEmpty ? odulluIos : _testOdulluIos);
}
