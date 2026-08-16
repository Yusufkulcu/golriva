import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reklam_sabitleri.dart';

/// Reklam akışı (yalnız Android/iOS). Birim kimlikleri: reklam_sabitleri.dart.
/// - ÖDÜLLÜ (isteğe bağlı): mağaza (+50 Riva) ve seri sonucu ekranı
///   (kazancı 2x / kaybı iade). Sunucudaki ORTAK günlük limite bağlı.
/// - GEÇİŞ (Faz 2.25): maç sonunda ödüllü İZLENMEDİYSE, ekrandan çıkarken
///   %50 ihtimalle otomatik geçiş reklamı — her maç türünde (ranked,
///   dostluk, lig); admin limitinden BAĞIMSIZ, sunucuya yazılmaz.
///   Ekran açılınca ön yüklenir (gecisOnYukle), çıkışta gösterilir.
class ReklamServis {
  static bool _baslatildi = false;
  static InterstitialAd? _hazirGecis;

  /// Son başarısızlığın insan-okur nedeni (tanı için) — başarıda null.
  static String? sonHata;

  static bool get destekleniyor => Platform.isAndroid || Platform.isIOS;

  static Future<void> _hazirla() async {
    if (_baslatildi) return;
    await MobileAds.instance.initialize();
    _baslatildi = true;
  }

  /// Ödüllü reklamı yükler ve gösterir.
  /// - Ödül KAZANILDIYSA benzersiz işlem kimliği döner (sunucuya iletilir).
  /// - Aksi halde null döner; neden [sonHata]'da yazar.
  static Future<String?> odulluGoster() async {
    if (!destekleniyor) {
      sonHata = 'platform desteklemiyor';
      return null;
    }
    try {
      await _hazirla();
    } catch (e) {
      sonHata = 'SDK başlatılamadı: $e';
      return null;
    }
    // ilk istek "no fill" verebilir — kısa arayla 3 deneme
    for (var deneme = 1; deneme <= 3; deneme++) {
      final ad = await _yukle();
      if (ad != null) return _goster(ad);
      if (deneme < 3) await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  static Future<RewardedAd?> _yukle() {
    final tamam = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: Platform.isAndroid
          ? ReklamSabitleri.odulluAndroidBirim
          : ReklamSabitleri.odulluIosBirim,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!tamam.isCompleted) tamam.complete(ad);
        },
        onAdFailedToLoad: (e) {
          // kod 0=iç hata, 1=geçersiz istek, 2=ağ hatası, 3=stok yok
          sonHata = 'yükleme (kod ${e.code}): ${e.message}';
          if (!tamam.isCompleted) tamam.complete(null);
        },
      ),
    );
    return tamam.future;
  }

  // ---------- FAZ 2.25: GEÇİŞ REKLAMI ----------

  /// Geçiş reklamını arka planda yükler (seri sonucu ekranı açılırken).
  /// Başarısızlık sessizdir — çıkışta gösterecek reklam olmaz, o kadar.
  static Future<void> gecisOnYukle() async {
    if (!destekleniyor || _hazirGecis != null) return;
    try {
      await _hazirla();
    } catch (_) {
      return;
    }
    final tamam = Completer<void>();
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? ReklamSabitleri.gecisAndroidBirim
          : ReklamSabitleri.gecisIosBirim,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _hazirGecis = ad;
          if (!tamam.isCompleted) tamam.complete();
        },
        onAdFailedToLoad: (e) {
          sonHata = 'geçiş yükleme (kod ${e.code}): ${e.message}';
          if (!tamam.isCompleted) tamam.complete();
        },
      ),
    );
    return tamam.future;
  }

  /// Ön yüklenmiş geçiş reklamını gösterir; kapanınca döner.
  /// Hazır reklam yoksa hemen false döner (kullanıcı bekletilmez).
  static Future<bool> gecisGoster() async {
    final ad = _hazirGecis;
    if (ad == null) return false;
    _hazirGecis = null;
    final tamam = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!tamam.isCompleted) tamam.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        sonHata = 'geçiş gösterim (kod ${e.code}): ${e.message}';
        a.dispose();
        if (!tamam.isCompleted) tamam.complete(false);
      },
    );
    try {
      await ad.show();
    } catch (e) {
      sonHata = 'geçiş show: $e';
      if (!tamam.isCompleted) tamam.complete(false);
    }
    return tamam.future;
  }

  /// Gösterilmeden vazgeçilen ön yüklemeyi bırak (ekran kapanınca).
  static void gecisBirak() {
    _hazirGecis?.dispose();
    _hazirGecis = null;
  }

  static Future<String?> _goster(RewardedAd ad) {
    final tamam = Completer<String?>();
    String? islem;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (islem == null) sonHata = 'reklam ödülden önce kapatıldı';
        if (!tamam.isCompleted) tamam.complete(islem);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        sonHata = 'gösterim (kod ${e.code}): ${e.message}';
        a.dispose();
        if (!tamam.isCompleted) tamam.complete(null);
      },
    );
    ad.show(onUserEarnedReward: (_, odul) {
      // ödül anı: benzersiz işlem kimliği — sunucudaki (ag, islem_id)
      // benzersiz kısıtı çift ödülü engeller
      sonHata = null;
      islem = 'r${DateTime.now().millisecondsSinceEpoch}-'
          '${identityHashCode(ad)}';
    });
    return tamam.future;
  }
}
