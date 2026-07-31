import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';

/// UYGULAMA ICI SATIN ALMA (Riva paketleri).
/// Urun kodlari magaza konsollarinda TANIMLI olmali (yoksa "ürün mağazada
/// tanımlı değil" hatasi normaldir):
///   Play Console  → Uygulama içi ürünler: riva_500, riva_1500, riva_5000
///   App Store Connect → In-App Purchases (Consumable): ayni kodlar
/// Sunucu tarafi: satin_alma_odul RPC (benzersiz islem kimligi — cift
/// odul imkansiz). Gercek makbuz dogrulamasi Faz 3.
class SatinAlmaServis {
  static final _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _abone;
  static Completer<({String? islemId, String? hata})>? _bekleyen;

  static bool get destekleniyor => Platform.isAndroid || Platform.isIOS;
  static String get magaza => Platform.isAndroid ? 'play' : 'appstore';

  /// Tek urunluk satin alma akisi. Basarida magaza islem kimligi doner.
  static Future<({String? islemId, String? hata})> satinAl(
      String urunKodu) async {
    if (!destekleniyor) {
      return (islemId: null, hata: 'Satın alma yalnız telefonda yapılır.');
    }
    if (!await _iap.isAvailable()) {
      return (islemId: null, hata: 'Mağaza şu an kullanılamıyor.');
    }
    if (_bekleyen != null) {
      return (islemId: null, hata: 'Devam eden bir satın alma var.');
    }
    _abone ??= _iap.purchaseStream.listen(_guncelleme);
    final cevap = await _iap.queryProductDetails({urunKodu});
    if (cevap.productDetails.isEmpty) {
      return (
        islemId: null,
        hata: 'Ürün mağazada tanımlı değil ($urunKodu) — mağaza konsolu '
            'kurulumu gerekiyor.'
      );
    }
    _bekleyen = Completer();
    try {
      await _iap.buyConsumable(
          purchaseParam:
              PurchaseParam(productDetails: cevap.productDetails.first));
    } catch (e) {
      _bekleyen = null;
      return (islemId: null, hata: 'Satın alma başlatılamadı: $e');
    }
    return _bekleyen!.future.timeout(const Duration(minutes: 3),
        onTimeout: () {
      _bekleyen = null;
      return (islemId: null, hata: 'Zaman aşımı — mağaza yanıt vermedi.');
    });
  }

  /// CANLI magaza fiyatlari (kullanicinin para birimiyle, or. ₺39,99).
  /// Magaza kapali/urun tanimsizsa bos harita doner — arayuz gorunum
  /// fiyatina (urunler.fiyat_metni) duser.
  static Future<Map<String, String>> fiyatlar(Set<String> kodlar) async {
    try {
      if (!destekleniyor || !await _iap.isAvailable()) return {};
      final cevap = await _iap.queryProductDetails(kodlar);
      return {for (final u in cevap.productDetails) u.id: u.price};
    } catch (_) {
      return {};
    }
  }

  static void _guncelleme(List<PurchaseDetails> liste) {
    for (final s in liste) {
      switch (s.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (s.pendingCompletePurchase) _iap.completePurchase(s);
          _bekleyen?.complete((
            islemId: s.purchaseID ?? 'p${s.transactionDate ?? ''}',
            hata: null
          ));
          _bekleyen = null;
        case PurchaseStatus.canceled:
          if (s.pendingCompletePurchase) _iap.completePurchase(s);
          _bekleyen?.complete((islemId: null, hata: 'Satın alma iptal edildi.'));
          _bekleyen = null;
        case PurchaseStatus.error:
          if (s.pendingCompletePurchase) _iap.completePurchase(s);
          _bekleyen?.complete(
              (islemId: null, hata: s.error?.message ?? 'satın alma hatası'));
          _bekleyen = null;
        case PurchaseStatus.pending:
          break; // magaza onayi bekleniyor — akis devam eder
      }
    }
  }
}
