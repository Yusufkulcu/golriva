import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../games/core/tr_norm.dart';

/// ikiz_data.json — Kariyer Ikizi veri seti.
/// P: [ad, dobGun(epoch gun), ulke, sari(-1 bilinmiyor), clAsist, clGol,
///     ligMac[6], ligGol[6], alias] — ligler: 6 lig adi.
class IkizOyuncu {
  final String ad;
  final int dobGun; // epoch'tan gun
  final String ulke;
  final int sari; // -1 = bilinmiyor
  final int clAsist;
  final int clGol;
  final List<int> ligMac;
  final List<int> ligGol;
  final String alias;
  final String normAd;
  final String normAlias;

  IkizOyuncu(this.ad, this.dobGun, this.ulke, this.sari, this.clAsist,
      this.clGol, this.ligMac, this.ligGol, this.alias)
      : normAd = trNorm(ad),
        normAlias = alias.isEmpty ? '' : trNorm(alias);

  /// "05.02.1985" gosterimi (UTC).
  String get dogumStr {
    final d = DateTime.fromMillisecondsSinceEpoch(dobGun * 86400000,
        isUtc: true);
    return '${d.day.toString().padLeft(2, "0")}.${d.month.toString().padLeft(2, "0")}.${d.year}';
  }
}

class IkizRepository {
  final List<String> ligler;
  final List<IkizOyuncu> oyuncular;
  IkizRepository._(this.ligler, this.oyuncular);

  static IkizRepository fromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    final ligler = (data['ligler'] as List).cast<String>();
    final oyuncular = (data['p'] as List)
        .map((e) => IkizOyuncu(
              e[0] as String,
              (e[1] as num).toInt(),
              e[2] as String,
              (e[3] as num).toInt(),
              (e[4] as num).toInt(),
              (e[5] as num).toInt(),
              (e[6] as List).map((x) => (x as num).toInt()).toList(),
              (e[7] as List).map((x) => (x as num).toInt()).toList(),
              (e.length > 8 ? e[8] as String : ''),
            ))
        .toList();
    return IkizRepository._(ligler, oyuncular);
  }

  static Future<IkizRepository> load() async => fromJsonString(
      await rootBundle.loadString('assets/data/ikiz_data.json'));
}
