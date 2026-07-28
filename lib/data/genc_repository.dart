import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// genc_data.json — Oyun 9 "En Genc Kadro" veri seti.
/// P: [ad, poz(K/D/O/F), dogumTarihi(YYYY-MM-DD, ''=yok), ulke, alias, aktif(1/0)]
/// C: [kulupAdi, [oyuncuIdx...], lig]
class GencOyuncu {
  final String ad;
  final String poz;
  final String dogumTarihi; // '' = yok
  final String ulke;
  final String alias;
  final bool aktif;
  final String normAd;
  final String normAlias;

  GencOyuncu(
      this.ad, this.poz, this.dogumTarihi, this.ulke, this.alias, this.aktif)
      : normAd = trNorm(ad),
        normAlias = alias.isEmpty ? '' : trNorm(alias);

  /// Yas OYNANIS ANINDA hesaplanir (proje ilkesi) — cagiran "simdi"yi verir.
  double? yas(DateTime simdi) {
    if (dogumTarihi.isEmpty) return null;
    final p = dogumTarihi.split('-').map(int.parse).toList();
    final dogum = DateTime(p[0], p[1], p[2]);
    return simdi.difference(dogum).inMilliseconds / (365.2422 * 24 * 3600 * 1000);
  }
}

class GencKulup {
  final String ad;
  final List<int> havuz;
  final String lig;
  GencKulup(this.ad, this.havuz, this.lig);
}

class GencRepository {
  final List<GencOyuncu> oyuncular;
  final List<GencKulup> kulupler;

  GencRepository._(this.oyuncular, this.kulupler);

  static GencRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final oyuncular = (data['p'] as List)
        .map((e) => GencOyuncu(
              e[0] as String,
              e[1] as String,
              e[2] as String,
              e[3] as String,
              e[4] as String,
              (e[5] as num).toInt() == 1,
            ))
        .toList();
    final kulupler = (data['c'] as List)
        .map((e) => GencKulup(e[0] as String,
            (e[1] as List).map((x) => (x as num).toInt()).toList(), e[2] as String))
        .toList();
    return GencRepository._(oyuncular, kulupler);
  }

  static Future<GencRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/genc_data.json');
    return fromJsonString(raw);
  }
}
