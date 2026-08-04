// Web / desteklenmeyen platform için no-op push bildirim servisi.
class BildirimServis {
  static bool get destekleniyor => false;

  /// Uygulama açılışında çağrılır (web'de hiçbir şey yapmaz).
  static Future<void> baslat() async {}

  /// Giriş/kayıt sonrası jetonu bu kullanıcıya bağlamak için.
  static Future<void> girisSonrasi() async {}

  /// Çıkışta bu cihazın jetonunu siler.
  static Future<void> cikistaTemizle() async {}
}
