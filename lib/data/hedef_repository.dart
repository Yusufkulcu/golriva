import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// hedef_data.json — Oyun 10 "Hedefi Tuttur" veri seti.
/// P: [ad, poz, ulke, dogumYili, alias, [14 deger]]
/// degerler sirasi: SLmac,SLgol,PLmac,PLgol,LaLigamac,LaLigagol,SerieAmac,
/// SerieAgol,Bundesmac,Bundesgol,L1mac,L1gol,SLigmac,SLiggol
/// cats: [kategoriAdi, degerIndexi] — hedef araligi RUNTIME hesaplanir (formul v2).
class HedefOyuncu {
  final String ad;
  final String poz;
  final String ulke;
  final int dogumYili;
  final String alias;
  final List<int> degerler;
  final String normAd;
  final String normAlias;

  HedefOyuncu(
      this.ad, this.poz, this.ulke, this.dogumYili, this.alias, this.degerler)
      : normAd = trNorm(ad),
        normAlias = alias.isEmpty ? '' : trNorm(alias);
}

class HedefKategori {
  final String ad; // or. "Şampiyonlar Ligi GOLÜ"
  final int degerIdx;
  HedefKategori(this.ad, this.degerIdx);

  /// "Şampiyonlar Ligi" + "GOLÜ" — tur kelimesi ayri ve iri gosterilir
  /// (Mert Günok karisikligi dersi: MAÇI/GOLÜ asla kucuk yazilmaz).
  String get govde =>
      ad.split(' ').sublist(0, ad.split(' ').length - 1).join(' ');
  String get tur => ad.split(' ').last;
}

class HedefRepository {
  final List<HedefOyuncu> oyuncular;
  final List<HedefKategori> kategoriler;

  /// TOPV[kategori] = o kategorinin en iyi 7 degerinin kumulatif toplami
  /// (hedef formulu v2: hedef = top-N toplaminin %40-65'i).
  late final List<List<int>> topDegerler;

  HedefRepository._(this.oyuncular, this.kategoriler) {
    topDegerler = kategoriler.map((c) {
      final vs = oyuncular.map((o) => o.degerler[c.degerIdx]).toList()
        ..sort((a, b) => b.compareTo(a));
      final acc = <int>[];
      var t = 0;
      for (final v in vs.take(7)) {
        t += v;
        acc.add(t);
      }
      return acc;
    }).toList();
  }

  static HedefRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final oyuncular = (data['p'] as List)
        .map((e) => HedefOyuncu(
              e[0] as String,
              e[1] as String,
              e[2] as String,
              (e[3] as num).toInt(),
              e[4] as String,
              (e[5] as List).map((x) => (x as num).toInt()).toList(),
            ))
        .toList();
    final kategoriler = (data['cats'] as List)
        .map((e) => HedefKategori(e[0] as String, (e[1] as num).toInt()))
        .toList();
    return HedefRepository._(oyuncular, kategoriler);
  }

  static Future<HedefRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/hedef_data.json');
    return fromJsonString(raw);
  }
}
