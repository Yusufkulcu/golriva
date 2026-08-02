import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_ayar.dart';

/// MERKEZI HATA RAPORLAMA (FAZ 2.8)
/// Kural: kullanici ASLA teknik hata metni gormez. Teknik detay (mesaj +
/// kisa yigin izi + sayfa/konum) sessizce Supabase'e gonderilir ve admin
/// panelinin HATALAR sekmesinde okunur. Sunucu tarafi: faz2_8_hata.sql.

/// pubspec.yaml surumuyle birlikte guncellenir.
const uygulamaSurumu = '1.0.0+2';

String get _platformAdi =>
    kIsWeb ? 'web' : defaultTargetPlatform.name; // android / ios / ...

/// Teknik hatayi admin'e raporlar. ASLA kendisi hata firlatmaz —
/// raporlayici patlarsa sessizce yutulur (aksi halde dongu olur).
Future<void> hataBildir(String sayfa, Object hata, [StackTrace? iz]) async {
  try {
    if (!SupabaseAyar.yapilandirildi) {
      // Cevrimdisi derleme: rapor gidecek yer yok; gelistirici konsolda gorur.
      debugPrint('[hata] $sayfa: $hata');
      return;
    }
    var mesaj = '$hata';
    if (iz != null) {
      final satirlar = '$iz'
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .take(6)
          .join('\n');
      if (satirlar.isNotEmpty) mesaj = '$mesaj\n$satirlar';
    }
    if (mesaj.length > 900) mesaj = mesaj.substring(0, 900);
    await Supabase.instance.client.rpc('hata_bildir', params: {
      'sayfa_p': sayfa,
      'mesaj_p': mesaj,
      'surum_p': uygulamaSurumu,
      'platform_p': _platformAdi,
    });
  } catch (_) {
    // sessiz: rapor gonderilemedi diye kullaniciyi rahatsiz etmeyiz.
  }
}

/// Kisa yol: hatayi raporlar, kullaniciya gosterilecek TEMIZ metni dondurur.
/// Ornek: `_mesaj(temizMesaj('magaza._reklam', e, 'Reklam şu an açılamıyor.'))`
String temizMesaj(String sayfa, Object hata, String mesaj, [StackTrace? iz]) {
  hataBildir(sayfa, hata, iz); // beklemeden gonder (fire-and-forget)
  return mesaj;
}
