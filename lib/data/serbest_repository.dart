import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// mac_data.json / milligol_data.json — serbest kadro oyunlari veri seti.
/// P: [ad, poz(K/D/O/F), deger(mac ya da milli gol), ulke, dogumYili, alias]
class SerbestOyuncu {
  final String ad;
  final String poz;
  final int deger;
  final String ulke;
  final int dogumYili;
  final String alias;
  final String normAd;
  final String normAlias;

  SerbestOyuncu(
      this.ad, this.poz, this.deger, this.ulke, this.dogumYili, this.alias)
      : normAd = trNorm(ad),
        normAlias = alias.isEmpty ? '' : trNorm(alias);
}

class SerbestRepository {
  final List<SerbestOyuncu> oyuncular;
  SerbestRepository._(this.oyuncular);

  static SerbestRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final oyuncular = (data['p'] as List)
        .map((e) => SerbestOyuncu(
              e[0] as String,
              e[1] as String,
              (e[2] as num).toInt(),
              e[3] as String,
              (e[4] as num).toInt(),
              (e.length > 5 ? e[5] as String : ''),
            ))
        .toList();
    return SerbestRepository._(oyuncular);
  }

  static Future<SerbestRepository> loadMac() async => fromJsonString(
      await rootBundle.loadString('assets/data/mac_data.json'));
  static Future<SerbestRepository> loadMilligol() async => fromJsonString(
      await rootBundle.loadString('assets/data/milligol_data.json'));
}
