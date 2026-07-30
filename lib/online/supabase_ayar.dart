/// Supabase yapilandirmasi — degerler DERLEME ANINDA verilir, koda gomulmez:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
/// Ikisi de bos ise uygulama TAMAMEN CEVRIMDISI calisir (hot-seat, bugunku
/// davranis) — testler ve CI hicbir zaman aga cikmaz.
/// GUVENLIK: buraya SADECE anon key girilir; service_role anahtari ASLA
/// istemciye konmaz (proje ilkesi — admin paneli yalnizca yerelde).
class SupabaseAyar {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get yapilandirildi => url.isNotEmpty && anonKey.isNotEmpty;
}
