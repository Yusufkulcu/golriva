import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob ODULLU REKLAM birimleri.
/// Varsayilanlar Google'in RESMI TEST kimlikleri — gelistirme icin guvenli,
/// gercek gelir icin AdMob hesabi acilinca --dart-define ile degistirilir:
///   --dart-define=REKLAM_ODUL_ANDROID=ca-app-pub-XXXX/YYYY
///   --dart-define=REKLAM_ODUL_IOS=ca-app-pub-XXXX/ZZZZ
/// (AndroidManifest.xml ve Info.plist'teki UYGULAMA kimlikleri de ayrica
/// gercek kimliklerle degistirilmeli.)
const _androidBirim = String.fromEnvironment('REKLAM_ODUL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917');
const _iosBirim = String.fromEnvironment('REKLAM_ODUL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313');

/// Maç sonu GEÇİŞ (interstitial) reklam birimleri — varsayılan Google TEST
/// kimlikleri. Gerçek gelir için AdMob'da interstitial birimi açıp:
///   --dart-define=REKLAM_GECIS_ANDROID=ca-app-pub-XXXX/YYYY
///   --dart-define=REKLAM_GECIS_IOS=ca-app-pub-XXXX/ZZZZ
const _gecisAndroid = String.fromEnvironment('REKLAM_GECIS_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712');
const _gecisIos = String.fromEnvironment('REKLAM_GECIS_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910');

/// Odullu reklam akisi (yalniz Android/iOS).
class ReklamServis {
  static bool _baslatildi = false;

  /// Son basarisizligin insan-okur nedeni (tani icin) — basarida null.
  static String? sonHata;

  static bool get destekleniyor => Platform.isAndroid || Platform.isIOS;

  static Future<void> _hazirla() async {
    if (_baslatildi) return;
    await MobileAds.instance.initialize();
    _baslatildi = true;
  }

  /// Odullu reklami yukler ve gosterir.
  /// - Odul KAZANILDIYSA benzersiz islem kimligi doner (sunucuya iletilir).
  /// - Aksi halde null doner; neden [sonHata]'da yazar.
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
    // ilk istek "no fill" verebilir — kisa arayla 3 deneme
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
      adUnitId: Platform.isAndroid ? _androidBirim : _iosBirim,
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

  // ───────── MAÇ SONU GEÇİŞ (INTERSTITIAL) REKLAMI ─────────
  static InterstitialAd? _gecis;
  static bool _gecisYukleniyor = false;

  /// Geçiş reklamını önceden yükler (maç bitmeden çağır ki hazır olsun).
  static void gecisHazirla() {
    if (!destekleniyor || _gecis != null || _gecisYukleniyor) return;
    _gecisYukleniyor = true;
    _hazirla().then((_) {
      InterstitialAd.load(
        adUnitId: Platform.isAndroid ? _gecisAndroid : _gecisIos,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _gecis = ad;
            _gecisYukleniyor = false;
          },
          onAdFailedToLoad: (e) {
            sonHata = 'geçiş yükleme (kod ${e.code}): ${e.message}';
            _gecis = null;
            _gecisYukleniyor = false;
          },
        ),
      );
    }).catchError((Object e) {
      sonHata = 'SDK başlatılamadı: $e';
      _gecisYukleniyor = false;
    });
  }

  /// Hazırsa geçiş reklamını gösterir. Gösterildiyse true döner.
  /// Sonraki maç için bir sonrakini de önceden yükler.
  static Future<bool> gecisGoster() async {
    final ad = _gecis;
    if (ad == null) {
      gecisHazirla(); // bir sonraki sefere hazır olsun
      return false;
    }
    _gecis = null;
    final tamam = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        gecisHazirla(); // sonraki maç için önden yükle
        if (!tamam.isCompleted) tamam.complete(true);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        sonHata = 'geçiş gösterim (kod ${e.code}): ${e.message}';
        a.dispose();
        gecisHazirla();
        if (!tamam.isCompleted) tamam.complete(false);
      },
    );
    ad.show();
    return tamam.future;
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
      // odul ani: benzersiz islem kimligi — sunucudaki (ag, islem_id)
      // benzersiz kisiti cift odulu engeller
      sonHata = null;
      islem = 'r${DateTime.now().millisecondsSinceEpoch}-'
          '${identityHashCode(ad)}';
    });
    return tamam.future;
  }
}
