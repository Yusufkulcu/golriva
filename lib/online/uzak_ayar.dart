import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hata_raporu.dart';
import 'supabase_ayar.dart';

/// FAZ 2.30 — UZAK AYARLAR (uzak_ayarlar tablosu, herkese açık okunur).
/// Açılışta bir kez yüklenir; okunamazsa VARSAYILANLAR kullanılır —
/// yani sunucu ulaşılamaz olsa bile uygulama kilitlenmez.
///
/// İki iş görür:
///  1) ZORUNLU MİNİMUM SÜRÜM: eski istemci mağazaya yönlendirilir
///     (yeni oyun/kural yayınlarında eski sürüm bozuk kalmaz).
///  2) AÇMA/KAPAMA anahtarları: patlayan özellik panelden anında kapanır
///     (OTA / mağaza güncellemesi beklenmez).
class UzakAyar {
  static String minSurumAndroid = '0.0.0';
  static String minSurumIos = '0.0.0';
  static bool bakimModu = false;
  static String bakimMesaj = '';
  static bool reklamAcik = true;
  static int gecisReklamYuzde = 50;
  static bool magazaAcik = true;
  static bool arkadasLigiAcik = true;
  static String magazaUrlAndroid =
      'https://play.google.com/store/apps/details?id=com.golriva';
  static String magazaUrlIos = 'https://apps.apple.com/app/golriva';

  /// Çalışan uygulamanın sürümü (main.dart PackageInfo ile doldurur).
  static String mevcutSurum = '0.0.0';

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static String get minSurum => _ios ? minSurumIos : minSurumAndroid;
  static String get magazaUrl => _ios ? magazaUrlIos : magazaUrlAndroid;

  /// Mevcut sürüm zorunlu minimumun altında mı?
  static bool get surumEski =>
      mevcutSurum != '0.0.0' && surumKiyasla(mevcutSurum, minSurum) < 0;

  /// 'a.b.c' biçimli sürümleri sayısal kıyaslar: <0 a küçük, 0 eşit, >0 a büyük.
  /// Eksik parçalar 0 sayılır; sayı olmayan parçalar 0 kabul edilir.
  static int surumKiyasla(String a, String b) {
    List<int> parcala(String s) => s
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.trim()) ?? 0)
        .toList();
    final pa = parcala(a), pb = parcala(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  static bool _bool(String? v, bool varsayilan) {
    if (v == null) return varsayilan;
    final t = v.trim().toLowerCase();
    if (t == '1' || t == 'true' || t == 'evet') return true;
    if (t == '0' || t == 'false' || t == 'hayir' || t == 'hayır') return false;
    return varsayilan;
  }

  /// Tabloyu oku ve alanları doldur. Hata/zaman aşımı → varsayılanlar.
  static Future<void> yukle() async {
    if (!SupabaseAyar.yapilandirildi) return;
    try {
      final r = await Supabase.instance.client
          .from('uzak_ayarlar')
          .select('anahtar, deger')
          .timeout(const Duration(seconds: 5));
      final m = <String, String>{
        for (final s in (r as List))
          s['anahtar'] as String: (s['deger'] ?? '') as String
      };
      uygula(m);
    } catch (e, s) {
      // sessiz: varsayılanlarla devam — ama raporla (sunucu tablosu
      // kurulmamış olabilir: supabase/faz2_30_uzak_ayar.sql)
      hataBildir('uzakAyar.yukle', e, s);
    }
  }

  /// Anahtar→değer haritasını alanlara işler (testlerde de kullanılır).
  static void uygula(Map<String, String> m) {
    String s(String k, String v) =>
        (m[k] == null || m[k]!.trim().isEmpty) ? v : m[k]!.trim();
    minSurumAndroid = s('min_surum_android', minSurumAndroid);
    minSurumIos = s('min_surum_ios', minSurumIos);
    bakimModu = _bool(m['bakim_modu'], bakimModu);
    bakimMesaj = s('bakim_mesaj', bakimMesaj);
    reklamAcik = _bool(m['reklam_acik'], reklamAcik);
    gecisReklamYuzde =
        (int.tryParse(s('gecis_reklam_yuzde', '$gecisReklamYuzde')) ??
                gecisReklamYuzde)
            .clamp(0, 100);
    magazaAcik = _bool(m['magaza_acik'], magazaAcik);
    arkadasLigiAcik = _bool(m['arkadas_ligi_acik'], arkadasLigiAcik);
    magazaUrlAndroid = s('magaza_url_android', magazaUrlAndroid);
    magazaUrlIos = s('magaza_url_ios', magazaUrlIos);
  }
}
