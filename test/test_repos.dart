import 'dart:io';
import 'package:golriva/data/genc_repository.dart';
import 'package:golriva/data/hedef_repository.dart';
import 'package:golriva/data/ikiz_repository.dart';
import 'package:golriva/data/kor_av_repository.dart';
import 'package:golriva/data/kupa_repository.dart';
import 'package:golriva/data/players_repository.dart';
import 'package:golriva/data/repos.dart';
import 'package:golriva/data/serbest_repository.dart';

/// Testler icin: tum veri setlerini DOSYADAN yukler (rootBundle yerine).
GolrivaRepos testRepos() {
  String oku(String ad) => File('assets/data/$ad').readAsStringSync();
  return GolrivaRepos(
    boy: PlayersRepository.fromJsonString(oku('boy_data.json')),
    genc: GencRepository.fromJsonString(oku('genc_data.json')),
    hedef: HedefRepository.fromJsonString(oku('hedef_data.json')),
    fee: KorAvRepository.fromJsonString(oku('fee_data.json')),
    card: KorAvRepository.fromJsonString(oku('card_data.json')),
    mac: SerbestRepository.fromJsonString(oku('mac_data.json')),
    milligol: SerbestRepository.fromJsonString(oku('milligol_data.json')),
    kupa: KupaRepository.fromJsonString(oku('draft_data.json')),
    ikiz: IkizRepository.fromJsonString(oku('ikiz_data.json')),
  );
}
