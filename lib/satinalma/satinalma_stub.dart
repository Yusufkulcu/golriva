/// Web ve desteklenmeyen platformlar icin satin alma taklidi.
/// Arayuz satinalma_mobil.dart ile BIREBIR ayni olmali.
class SatinAlmaServis {
  static bool get destekleniyor => false;
  static String get magaza => 'play';

  static void Function(String urunKodu, String islemId)? onArkaPlanSatinAlma;

  static void baslat() {}

  static Future<({String? islemId, String? hata})> satinAl(
          String urunKodu) async =>
      (islemId: null, hata: 'Satın alma yalnız telefonda yapılır.');

  static Future<void> geriYukle() async {}

  /// Magaza fiyatlari — stub'da bos (uygulama gorunum fiyatina duser).
  static Future<Map<String, String>> fiyatlar(Set<String> kodlar) async => {};
}
