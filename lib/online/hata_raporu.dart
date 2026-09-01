import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_ayar.dart';

/// MERKEZI HATA RAPORLAMA (FAZ 2.8 → FAZ 2.31: seviyeli)
/// Kural: kullanici ASLA teknik hata metni gormez. Teknik detay (mesaj +
/// kisa yigin izi + sayfa/konum) sessizce Supabase'e gonderilir ve admin
/// panelinin HATALAR sekmesinde SEVİYEYE göre okunur:
///   kritik — çökme/kod hatası (null check, tip, aralık, yakalanmamış)
///   hata   — işlev başarısız (varsayılan)
///   uyari  — kullanıcı/cihaz kaynaklı (saat yanlış, boş alan, yanlış şifre)
///   bilgi  — bilinen gürültü (ağ soketi, kapanmış maça hamle, reklam stoku)
/// Sunucu tarafi: faz2_8_hata.sql + faz2_31_hata_seviye.sql.

/// Çalışan uygulamanın sürümü — main.dart PackageInfo ile doldurur
/// ('1.1.0+11'). Eskiden elle yazılan sabitti ve güncellenmiyordu.
String uygulamaSurumu = '?';

String get _platformAdi =>
    kIsWeb ? 'web' : defaultTargetPlatform.name; // android / ios / ...

/// Mesaj/konuma bakarak otomatik seviye. Açık [seviye] verilirse o kazanır.
String hataSeviyesi(String sayfa, String mesaj) {
  final m = mesaj.toLowerCase();
  // bilinen GÜRÜLTÜ — işlev etkilenmez, panelde "bilgi" altında birikir
  const bilgi = [
    'bad file descriptor',
    'socketexception',
    'connection reset',
    'connection closed',
    'network is unreachable',
    'apns-token-not-set',
    'maç uygun değil',
    'no ad to show',
    'kod 3)', // reklam: stok yok
  ];
  for (final k in bilgi) {
    if (m.contains(k)) return 'bilgi';
  }
  // kullanıcı / cihaz kaynaklı
  const uyari = [
    'issued at future', // cihaz saati ileri
    'validation_failed',
    'invalid login',
    'missing email',
    'requires either a token',
    'duplicate',
    '23505',
    'yetersiz bakiye',
  ];
  for (final k in uyari) {
    if (m.contains(k)) return 'uyari';
  }
  // kod hatası / çökme
  const kritik = [
    'null check operator',
    'rangeerror',
    'nosuchmethoderror',
    'is not a subtype',
    'stack overflow',
    'assertion failed',
    'late initialization',
  ];
  if (sayfa.startsWith('global.')) return 'kritik';
  for (final k in kritik) {
    if (m.contains(k)) return 'kritik';
  }
  return 'hata';
}

/// Teknik hatayi admin'e raporlar. ASLA kendisi hata firlatmaz —
/// raporlayici patlarsa sessizce yutulur (aksi halde dongu olur).
Future<void> hataBildir(String sayfa, Object hata,
    [StackTrace? iz, String? seviye]) async {
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
      'seviye_p': seviye ?? hataSeviyesi(sayfa, '$hata'),
    });
  } catch (_) {
    // sessiz: rapor gonderilemedi diye kullaniciyi rahatsiz etmeyiz.
  }
}

/// Kisa yol: hatayi raporlar, kullaniciya gosterilecek TEMIZ metni dondurur.
/// Ornek: `_mesaj(temizMesaj('magaza._reklam', e, 'Reklam şu an açılamıyor.'))`
/// CİHAZ SAATİ: 'JWT issued at future' → sabit metin yerine saat uyarısı
/// döner (kullanıcı kendi düzeltebilir; başka hiçbir mesaj ona yardım etmez).
String temizMesaj(String sayfa, Object hata, String mesaj, [StackTrace? iz]) {
  hataBildir(sayfa, hata, iz); // beklemeden gonder (fire-and-forget)
  if ('$hata'.contains('issued at future')) return saatUyarisi;
  return mesaj;
}

/// Cihaz saati sunucudan ileride (JWT reddi) — kullanıcıya yol gösteren metin.
const saatUyarisi = 'Cihazının saati yanlış görünüyor. Ayarlar → Genel → '
    'Tarih ve Saat → "Otomatik ayarla"yı açıp tekrar dene.';
