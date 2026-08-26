import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../online/hata_raporu.dart';

/// UYGULAMA ICI SATIN ALMA (Riva paketleri).
/// Urun kodlari magaza konsollarinda TANIMLI olmali (yoksa "ürün mağazada
/// tanımlı değil" hatasi normaldir):
///   Play Console  → Uygulama içi ürünler: riva_500, riva_1500, riva_5000
///   App Store Connect → In-App Purchases (Consumable): ayni kodlar
///     + ürünler SÜRÜME EKLİ ve "Ready to Submit" olmalı, Ücretli Uygulama
///     Sözleşmesi imzalı olmalı — yoksa StoreKit ürün listesi BOŞ döner.
/// Sunucu tarafi: satin_alma_odul RPC (benzersiz islem kimligi — cift
/// odul imkansiz). Gercek makbuz dogrulamasi Faz 3.
///
/// iOS İNCELEME DÜZELTMESİ (Apple reddi):
///   * purchaseStream artık UYGULAMA AÇILIŞINDA dinlenir ([baslat]) —
///     StoreKit, uygulama kapanırken yarım kalan işlemleri bir sonraki
///     açılışta yeniden teslim eder; dinleyen yoksa işlem "takılı" kalır ve
///     sonraki satın almalar tamamlanmaz. Bu kayıtlar [onArkaPlanSatinAlma]
///     ile sunucuya işlenir (benzersiz islem kimliği çift ödülü engeller).
///   * [geriYukle]: Apple'ın istediği "Satın alımları geri yükle" yolu.
class SatinAlmaServis {
  static final _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _abone;
  static Completer<({String? islemId, String? hata})>? _bekleyen;

  /// Açılışta teslim edilen (bekleyen bir satın alma akışına ait OLMAYAN)
  /// tamamlanmış işlemler için geri çağrı: (urunKodu, islemId).
  /// main.dart bunu sunucuya satin_alma_odul ile işler.
  static void Function(String urunKodu, String islemId)? onArkaPlanSatinAlma;

  static bool get destekleniyor => Platform.isAndroid || Platform.isIOS;
  static String get magaza => Platform.isAndroid ? 'play' : 'appstore';

  /// Uygulama açılışında çağrılır: mağaza akışını dinlemeye başlar.
  /// (Tekrar çağrılması zararsız.)
  static void baslat() {
    if (!destekleniyor) return;
    _abone ??= _iap.purchaseStream.listen(_guncelleme,
        onError: (Object e, StackTrace s) =>
            hataBildir('satinalma.akis.stream', e, s));
  }

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
    baslat();
    final cevap = await _iap.queryProductDetails({urunKodu});
    if (cevap.productDetails.isEmpty) {
      // Teknik neden (urun magaza konsolunda tanimsiz / sürüme ekli değil)
      // admin'e raporlanir.
      return (
        islemId: null,
        hata: temizMesaj('satinalma.urun',
            'urun magazada tanimli degil: $urunKodu '
            '(notFound: ${cevap.notFoundIDs}, hata: ${cevap.error?.message})',
            'Bu paket şu an satın alınamıyor — birazdan tekrar dene.')
      );
    }
    _bekleyen = Completer();
    try {
      await _iap.buyConsumable(
          purchaseParam:
              PurchaseParam(productDetails: cevap.productDetails.first));
    } catch (e, s) {
      _bekleyen = null;
      return (
        islemId: null,
        hata: temizMesaj('satinalma.baslat', e,
            'Satın alma başlatılamadı — tekrar dene.', s)
      );
    }
    return _bekleyen!.future.timeout(const Duration(minutes: 3),
        onTimeout: () {
      _bekleyen = null;
      return (islemId: null, hata: 'Zaman aşımı — mağaza yanıt vermedi.');
    });
  }

  /// Satın alımları geri yükle (App Store kuralı). Tüketilebilir
  /// ürünlerde genelde geri yüklenecek bir şey yoktur; yine de akış
  /// tetiklenir, varsa kayıtlar [onArkaPlanSatinAlma] ile işlenir.
  static Future<void> geriYukle() async {
    if (!destekleniyor || !await _iap.isAvailable()) return;
    baslat();
    await _iap.restorePurchases();
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
          final islemId = s.purchaseID ?? 'p${s.transactionDate ?? ''}';
          if (_bekleyen != null) {
            _bekleyen!.complete((islemId: islemId, hata: null));
            _bekleyen = null;
          } else {
            // açılışta teslim edilen yarım işlem ya da geri yükleme:
            // sunucuya işle (benzersiz islem kimliği → çift ödül yok)
            onArkaPlanSatinAlma?.call(s.productID, islemId);
          }
          // ÖNEMLİ: mağazaya "tamamlandı" de — yoksa iOS işlemi tekrar
          // tekrar teslim eder ve kuyruğu tıkar
          if (s.pendingCompletePurchase) _iap.completePurchase(s);
        case PurchaseStatus.canceled:
          if (s.pendingCompletePurchase) _iap.completePurchase(s);
          _bekleyen?.complete((islemId: null, hata: 'Satın alma iptal edildi.'));
          _bekleyen = null;
        case PurchaseStatus.error:
          if (s.pendingCompletePurchase) _iap.completePurchase(s);
          _bekleyen?.complete((
            islemId: null,
            hata: temizMesaj('satinalma.akis',
                s.error?.message ?? 'satin alma hatasi (detaysiz)',
                'Satın alma tamamlanamadı — birazdan tekrar dene.')
          ));
          _bekleyen = null;
        case PurchaseStatus.pending:
          break; // magaza onayi bekleniyor — akis devam eder
      }
    }
  }
}
