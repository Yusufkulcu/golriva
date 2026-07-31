/// Web ve desteklenmeyen platformlar icin reklam servisi taklidi.
/// Arayuz reklam_mobil.dart ile BIREBIR ayni olmali.
class ReklamServis {
  static bool get destekleniyor => false;

  /// Odullu reklami gosterir; odul kazanildiysa islem kimligi doner.
  /// Stub her zaman null doner (reklam yok).
  static Future<String?> odulluGoster() async => null;
}
