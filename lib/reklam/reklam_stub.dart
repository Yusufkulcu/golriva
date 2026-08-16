/// Web ve desteklenmeyen platformlar icin reklam servisi taklidi.
/// Arayuz reklam_mobil.dart ile BIREBIR ayni olmali.
class ReklamServis {
  static bool get destekleniyor => false;

  /// Son basarisizligin nedeni — stub'da her zaman null.
  static String? sonHata;

  /// Odullu reklami gosterir; odul kazanildiysa islem kimligi doner.
  /// Stub her zaman null doner (reklam yok).
  static Future<String?> odulluGoster() async => null;

  /// Faz 2.25 gecis reklami — stub'da yok.
  static Future<void> gecisOnYukle() async {}
  static Future<bool> gecisGoster() async => false;
  static void gecisBirak() {}
}
