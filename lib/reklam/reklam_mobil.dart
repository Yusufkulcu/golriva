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

/// Odullu reklam akisi (yalniz Android/iOS).
class ReklamServis {
  static bool _baslatildi = false;

  static bool get destekleniyor => Platform.isAndroid || Platform.isIOS;

  /// Odullu reklami yukler ve gosterir.
  /// - Odul KAZANILDIYSA benzersiz islem kimligi doner (sunucuya iletilir).
  /// - Reklam yuklenemedi / erken kapatildi / odul yoksa null doner.
  static Future<String?> odulluGoster() async {
    if (!destekleniyor) return null;
    if (!_baslatildi) {
      await MobileAds.instance.initialize();
      _baslatildi = true;
    }
    final tamam = Completer<String?>();
    await RewardedAd.load(
      adUnitId: Platform.isAndroid ? _androidBirim : _iosBirim,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          String? islem;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              if (!tamam.isCompleted) tamam.complete(islem);
            },
            onAdFailedToShowFullScreenContent: (a, e) {
              a.dispose();
              if (!tamam.isCompleted) tamam.complete(null);
            },
          );
          ad.show(onUserEarnedReward: (_, odul) {
            // odul ani: benzersiz islem kimligi uret — sunucudaki
            // (ag, islem_id) benzersiz kisiti cift odulu engeller
            islem = 'r${DateTime.now().millisecondsSinceEpoch}-'
                '${identityHashCode(ad)}';
          });
        },
        onAdFailedToLoad: (e) {
          if (!tamam.isCompleted) tamam.complete(null);
        },
      ),
    );
    return tamam.future;
  }
}
