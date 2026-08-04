import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey, mesajKey;
import 'bildirim_servis.dart';
import 'hata_raporu.dart';
import 'online_servis.dart';
import 'supabase_ayar.dart';

/// TEK CİHAZ OTURUMU BEKÇİSİ (anti-hile).
/// Bir hesap aynı anda tek cihazda aktif olur. Başka cihazdan giriş yapılınca
/// bu cihaz kendini yoklar ve otomatik çıkış yapar (uygulama açık olsa bile).
///
/// Cihaz kimliği her açılışta üretilir (kalıcı depoya gerek yok): son giren
/// cihaz "aktif" olur; diğerleri periyodik yoklamada / öne gelişte / kuyruğa
/// girişte kendini kontrol edip çıkar.
class OturumBekcisi with WidgetsBindingObserver {
  OturumBekcisi._();
  static final OturumBekcisi _i = OturumBekcisi._();
  factory OturumBekcisi() => _i;

  /// Bu cihaza/oturuma özel kimlik (her uygulama açılışında yeni).
  final String cihazId =
      'c${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';

  Timer? _zaman;
  bool _calisiyor = false;
  bool _kovuluyor = false;

  /// Giriş sonrası + uygulama açılışında çağrılır: bu cihazı AKTİF yapar
  /// ve yoklamayı başlatır.
  Future<void> baslat() async {
    if (!SupabaseAyar.yapilandirildi || !OnlineServis().girisYapildi) return;
    await OnlineServis().oturumSahiplen(cihazId);
    if (_calisiyor) return;
    _calisiyor = true;
    WidgetsBinding.instance.addObserver(this);
    _zaman = Timer.periodic(const Duration(seconds: 15), (_) => dogrula());
  }

  void durdur() {
    _zaman?.cancel();
    _zaman = null;
    if (_calisiyor) {
      WidgetsBinding.instance.removeObserver(this);
      _calisiyor = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) dogrula();
  }

  /// Bu cihaz hâlâ aktif mi kontrol eder. Değilse çıkış yaptırır.
  /// true → devam edilebilir; false → başka cihaz devraldı (çıkış yapıldı).
  Future<bool> dogrula() async {
    if (!OnlineServis().girisYapildi) return true;
    final benim = await OnlineServis().oturumBenimMi(cihazId);
    if (!benim) {
      await _kov();
      return false;
    }
    return true;
  }

  Future<void> _kov() async {
    if (_kovuluyor) return;
    _kovuluyor = true;
    durdur();
    try {
      await BildirimServis.cikistaTemizle();
    } catch (_) {}
    try {
      await OnlineServis().cikisYap();
    } catch (e, s) {
      hataBildir('oturum._kov', e, s);
    }
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
    mesajKey.currentState?.showSnackBar(const SnackBar(
        content: Text('Bu hesaba başka bir cihazdan giriş yapıldı — '
            'güvenlik için çıkış yapıldı.')));
    _kovuluyor = false;
  }
}
