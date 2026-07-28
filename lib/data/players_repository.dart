import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// boy_data.json — Oyun 7/8 veri seti.
/// P: [ad, poz(K/D/O/F), boyCm(0=bilinmiyor), ulke, dogumYili, alias]
/// C: [kulupAdi, [oyuncuIdx...], lig] — L: [ligAdi, [oyuncuIdx...]]
class Oyuncu {
  final String ad;
  final String poz;
  final int boyCm; // 0 = bilinmiyor
  final String ulke;
  final int dogumYili;
  final String alias;
  final String normAd;
  final String normAlias;

  Oyuncu(this.ad, this.poz, this.boyCm, this.ulke, this.dogumYili, this.alias)
      : normAd = trNorm(ad),
        normAlias = alias.isEmpty ? '' : trNorm(alias);
}

class Kulup {
  final String ad;
  final List<int> havuz;
  final String lig;
  Kulup(this.ad, this.havuz, this.lig);
}

class Lig {
  final String ad;
  final List<int> havuz;
  Lig(this.ad, this.havuz);
}

class PlayersRepository {
  final List<Oyuncu> oyuncular;
  final List<Kulup> kulupler;
  final List<Lig> ligler;

  PlayersRepository._(this.oyuncular, this.kulupler, this.ligler);

  static PlayersRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final oyuncular = (data['p'] as List)
        .map((e) => Oyuncu(
              e[0] as String,
              e[1] as String,
              (e[2] as num).toInt(),
              e[3] as String,
              (e[4] as num).toInt(),
              e[5] as String,
            ))
        .toList();
    final kulupler = (data['c'] as List)
        .map((e) => Kulup(e[0] as String,
            (e[1] as List).map((x) => (x as num).toInt()).toList(), e[2] as String))
        .toList();
    final ligler = (data['l'] as List)
        .map((e) => Lig(e[0] as String,
            (e[1] as List).map((x) => (x as num).toInt()).toList()))
        .toList();
    return PlayersRepository._(oyuncular, kulupler, ligler);
  }

  static Future<PlayersRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/boy_data.json');
    return fromJsonString(raw);
  }
}
