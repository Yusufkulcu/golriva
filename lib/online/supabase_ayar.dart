/// Supabase yapilandirmasi — degerler DERLEME ANINDA verilir, koda gomulmez:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_...
/// Anahtar iki bicimde de olabilir (ikisi de calisir):
///   - YENI sistem: "Publishable key" (sb_publishable_... — yeni projelerde bu var)
///   - ESKI sistem: "anon public" JWT (eyJ... — eski projeler/Legacy API Keys)
/// SUPABASE_ANON_KEY adi da geriye uyumluluk icin kabul edilir.
/// Ikisi de bos ise uygulama TAMAMEN CEVRIMDISI calisir (hot-seat) —
/// testler ve CI hicbir zaman aga cikmaz.
/// GUVENLIK: buraya SADECE publishable/anon anahtari girilir; secret/service_role
/// anahtari ASLA istemciye konmaz (proje ilkesi — admin paneli yalnizca yerelde).
class SupabaseAyar {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const _yeniAd = String.fromEnvironment('SUPABASE_KEY');
  static const _eskiAd = String.fromEnvironment('SUPABASE_ANON_KEY');
  static String get anahtar => _yeniAd.isNotEmpty ? _yeniAd : _eskiAd;

  /// sb_publishable_/sb_... onekli anahtarlar YENI sistemdir.
  static bool get yeniAnahtarSistemi => anahtar.startsWith('sb_');
  static bool get yapilandirildi => url.isNotEmpty && anahtar.isNotEmpty;
}
