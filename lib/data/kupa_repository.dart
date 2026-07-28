import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// draft_data.json — Kupa Drafti veri seti.
/// P: [ad, poz(K/D/O/F), kupa, ulke, yas] — C: [kulupAdi, [idx...], lig]
class KupaOyuncu {
  final String ad;
  final String poz;
  final int kupa;
  final String ulke;
  final int yas;
  final String normAd;

  KupaOyuncu(this.ad, this.poz, this.kupa, this.ulke, this.yas)
      : normAd = trNorm(ad);
}

class KupaKulup {
  final String ad;
  final List<int> havuz;
  final String lig;
  KupaKulup(this.ad, this.havuz, this.lig);
}

class KupaRepository {
  final List<KupaOyuncu> oyuncular;
  final List<KupaKulup> kulupler;
  KupaRepository._(this.oyuncular, this.kulupler);

  static KupaRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final oyuncular = (data['p'] as List)
        .map((e) => KupaOyuncu(
              e[0] as String,
              e[1] as String,
              (e[2] as num).toInt(),
              e[3] as String,
              (e[4] as num).toInt(),
            ))
        .toList();
    final kulupler = (data['c'] as List)
        .map((e) => KupaKulup(e[0] as String,
            (e[1] as List).map((x) => (x as num).toInt()).toList(),
            e.length > 2 ? e[2] as String : ''))
        .toList();
    return KupaRepository._(oyuncular, kulupler);
  }

  static Future<KupaRepository> load() async => fromJsonString(
      await rootBundle.loadString('assets/data/draft_data.json'));
}
