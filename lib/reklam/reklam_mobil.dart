import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'reklam_sabitleri.dart';

/// Ödüllü reklam akışı (yalnız Android/iOS).
/// Faz 2.20: maç sonu OTOMATİK geçiş reklamı KALDIRILDI — tüm reklamlar
/// artık İSTEĞE BAĞLI ödüllü: mağaza (+50 Riva) ve seri sonucu ekranı
/// (kazancı 2x / kaybı iade). Birim kimlikleri: reklam_sabitleri.dart.
class ReklamServis {
  static bool _baslatildi = false;

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
