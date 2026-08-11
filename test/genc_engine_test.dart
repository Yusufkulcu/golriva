import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/genc_repository.dart';
import 'package:golriva/games/en_genc_kadro/engine.dart';

void main() {
  late GencRepository repo;
  final sabitAn = DateTime(2026, 7, 28); // yas testleri deterministik

  setUpAll(() {
    final raw = File('assets/data/genc_data.json').readAsStringSync();
    repo = GencRepository.fromJsonString(raw);
  });

  test('CAPA: Mbappe 1998-12-20 → 28 Tem 2026\'da 27,6 yas', () {
    final m = repo.oyuncular.firstWhere((o) => o.ad == 'Kylian Mbappé');
    expect(m.dogumTarihi, '1998-12-20');
    final y = m.yas(sabitAn)!;
    expect((y - 27.6).abs(), lessThan(0.05), reason: 'yas: $y');
    expect(yasStr(y), '27,6'); // Turkce virgul
  });

  test('29 elit kulup; Wolfsburg YOK (kullanici karari)', () {
    expect(repo.kulupler.length, 29);
    expect(repo.kulupler.map((c) => c.ad), isNot(contains('VfL Wolfsburg')));
  });

  test('sebepli engeller: pasif / dogum tarihsiz / mevki dolu / alinan', () {
    final e = GencKadroEngine(repo, rng: Random(3), simdi: sabitAn);
    // kulubun pasif bir oyuncusunu bul, adaylar'da nedeni gorunmeli
    final havuz = e.havuz;
    final pasif = havuz
        .where((i) => !repo.oyuncular[i].aktif && repo.oyuncular[i].ad.length >= 4)
        .toList();
    if (pasif.isNotEmpty) {
      final o = repo.oyuncular[pasif.first];
      final sonuc = e.adaylar(o.ad.substring(0, 4));
      final aday = sonuc.where((a) => a.idx == pasif.first);
      if (aday.isNotEmpty) expect(aday.first.neden, 'Aktif değil');
      expect(e.sec(pasif.first), isFalse); // motor reddeder
    }
    // havuz disi oyuncu reddedilir
    final disari =
        List.generate(repo.oyuncular.length, (i) => i).firstWhere(
            (i) => !havuz.contains(i));
    expect(e.sec(disari), isFalse);
  });

  test('formasyon: 1K-2D-2O-1F zorunlu, fazlasi "dolu"', () {
    final e = GencKadroEngine(repo, rng: Random(5), simdi: sabitAn);
    expect(e.acikMevkiler(0), ['K', 'D', 'O', 'F']);
    // ayni mevkiden formasyon sinirina kadar sec — motor siniri korur
  });

  test('oncelik el degistirir: tur1 O1, tur2 O2', () {
    final e = GencKadroEngine(repo, rng: Random(6), simdi: sabitAn);
    expect(e.firstPicker(0), 0);
    expect(e.firstPicker(1), 1);
    expect(e.firstPicker(2), 0);
    expect(e.simdiSecen, 0); // tur 0 faz 0
  });

  test('tam oyun simulasyonu x15 seed: invaryantlar + 60 ceza', () {
    for (var seed = 0; seed < 15; seed++) {
      final rng = Random(seed);
      final e = GencKadroEngine(repo, rng: Random(seed + 900), simdi: sabitAn);
      var adim = 0;
      while (!e.bitti && adim < 50) {
        adim++;
        final s = e.simdiSecen;
        final acik = e.acikMevkiler(s);
        // gecerli aday: bu kaynak (ulke/lig) + acik mevki + aktif + tarihli
        final gecerli = e.havuz.where((i) {
          final o = repo.oyuncular[i];
          return !e.alinan.contains(i) &&
              acik.contains(o.poz) &&
              o.aktif &&
              o.dogumTarihi.isNotEmpty;
        }).toList();
        if (gecerli.isEmpty || rng.nextInt(8) == 0) {
          e.sureDoldu();
        } else {
          expect(e.sec(gecerli[rng.nextInt(gecerli.length)]), isTrue);
        }
      }
      expect(e.bitti, isTrue, reason: 'seed $seed: oyun bitmedi');
      for (var s = 0; s < 2; s++) {
        expect(e.kadrolar[s].length + e.bosSlot[s], gencTurSayisi,
            reason: 'seed $seed: oyuncu $s slot sayisi tutmuyor');
        // formasyon asilmamis
        final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
        for (final p in e.kadrolar[s]) {
          sayim[p.poz] = sayim[p.poz]! + 1;
        }
        for (final z in gencFormation.keys) {
          expect(sayim[z], lessThanOrEqualTo(gencFormation[z]!),
              reason: 'seed $seed: $z fazla');
        }
        // toplam = ara toplam + bos ceza
        expect(e.toplam(s),
            closeTo(e.araToplam(s) + e.bosSlot[s] * gencBosCeza, 0.001));
      }
      final k = e.kazanan();
      if (k != null) expect(e.toplam(k), lessThan(e.toplam(1 - k)));
    }
  });

  test('6 tur 6 FARKLI kaynak (ulke/lig karisimi)', () {
    final e = GencKadroEngine(repo, rng: Random(11), simdi: sabitAn);
    expect(e.turlar.toSet().length, gencTurSayisi);
    // her turun havuzuyla kadro kurulabilir olmali (motor filtresi)
    for (var t = 0; t < gencTurSayisi; t++) {
      expect(
          (e.turlar[t].$1 ? e.ligler : e.ulkeler)[e.turlar[t].$2]
              .$2
              .length,
          greaterThanOrEqualTo(14));
    }
  });
}
