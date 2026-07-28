import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// fee_data.json / card_data.json — Bonservis Avi & Sari Kart Avi veri seti.
/// P: [ad, deger(feeM ya da sari kart), ulke, mevkiAd, dogumYili, alias]
class KorAvOyuncu {
  final String ad;
  final double deger;
  final String ulke;
  final String mevkiAd; // "Forvet" gibi tam ad
  final int dogumYili;
  final String alias;
  final String normAd;
  final String normAlias;

  KorAvOyuncu(
      this.ad, this.deger, this.ulke, this.mevkiAd, this.dogumYili, this.alias)
      : normAd = trNorm(ad),
        normAlias = alias.isEmpty ? '' : trNorm(alias);
}

class KorAvRepository {
  final List<KorAvOyuncu> oyuncular;

  /// top-6 kumulatif toplam (hedef formulu v2 icin)
  late final List<double> topDegerler;

  KorAvRepository._(this.oyuncular) {
    final vs = oyuncular.map((o) => o.deger).toList()
      ..sort((a, b) => b.compareTo(a));
    final acc = <double>[];
    var t = 0.0;
    for (final v in vs.take(6)) {
      t += v;
      acc.add(t);
    }
    topDegerler = acc;
  }

  static KorAvRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final oyuncular = (data['p'] as List)
        .map((e) => KorAvOyuncu(
              e[0] as String,
              (e[1] as num).toDouble(),
              e[2] as String,
              e[3] as String,
              (e[4] as num).toInt(),
              (e.length > 5 ? e[5] as String : ''),
            ))
        .toList();
    return KorAvRepository._(oyuncular);
  }

  static Future<KorAvRepository> loadFee() async => fromJsonString(
      await rootBundle.loadString('assets/data/fee_data.json'));
  static Future<KorAvRepository> loadCard() async => fromJsonString(
      await rootBundle.loadString('assets/data/card_data.json'));
}
