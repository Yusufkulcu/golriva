import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/repos.dart';
import 'package:golriva/games/bayrak_yarisi/engine.dart';
import 'package:golriva/games/kariyer_ikizi/engine.dart';
import 'package:golriva/games/kor_av/engine.dart';
import 'package:golriva/games/kupa_drafti/engine.dart';
import 'package:golriva/games/serbest_kadro/engine.dart';
import 'test_repos.dart';

/// 5 yeni oyun ailesinin motor testleri:
/// Kor Av (Bonservis + Sari Kart), Serbest Kadro (Mac + Milli Gol),
/// Kupa Drafti, Bayrak Yarisi, Kariyer Ikizi.
void main() {
  late GolrivaRepos repos;

  setUpAll(() {
    repos = testRepos();
  });

  group('KOR AV (Bonservis + Sari Kart)', () {
    test('CAPA: Mbappe 180 M€, CR7 120 sari kart', () {
      expect(
          repos.fee.oyuncular
              .firstWhere((o) => o.ad == 'Kylian Mbappé')
              .deger,
          180.0);
      expect(
          repos.card.oyuncular
              .firstWhere((o) => o.ad == 'Cristiano Ronaldo')
              .deger,
          120.0);
    });

    test('hedef v2: N=4-6 tum tohumlarda erisilebilir + tam onluk', () {
      for (final repo in [repos.fee, repos.card]) {
        for (var n = 4; n <= 6; n++) {
          for (var seed = 0; seed < 25; seed++) {
            final e = KorAvEngine(repo, rng: Random(seed), sabitN: n);
            final maxN = repo.topDegerler[n - 1];
            expect(e.hedef % 10, 0);
            expect(e.hedef, lessThanOrEqualTo(maxN));
            expect(e.hedef,
                greaterThanOrEqualTo((0.40 * maxN / 10).ceil() * 10));
          }
        }
      }
    });

    test('tam oyun simulasyonu x12 seed: invaryantlar', () {
      for (var seed = 0; seed < 12; seed++) {
        final rng = Random(seed);
        final e = KorAvEngine(repos.fee, rng: Random(seed + 100));
        var adim = 0;
        while (!e.bitti && adim++ < 60) {
          if (rng.nextInt(10) == 0) {
            e.sureDoldu();
          } else {
            int i;
            do {
              i = rng.nextInt(repos.fee.oyuncular.length);
            } while (e.alinan.contains(i));
            expect(e.sec(i), isTrue);
          }
        }
        expect(e.bitti, isTrue);
        for (var s = 0; s < 2; s++) {
          expect(e.secimler[s].length + e.yanan[s], e.kadroN);
        }
        final k = e.kazanan();
        if (k != null) expect(e.fark(k), lessThan(e.fark(1 - k)));
        expect(e.acilisSirasi().length,
            e.secimler[0].length + e.secimler[1].length);
      }
    });

    test('kap-kac + kor meta + TR arama', () {
      final e = KorAvEngine(repos.fee, rng: Random(3));
      expect(e.adaylar('me'), isEmpty);
      final m = e
          .adaylar('mbappe')
          .firstWhere((a) => repos.fee.oyuncular[a.idx].ad == 'Kylian Mbappé');
      expect(m.neden, isNull);
      expect(e.sec(m.idx), isTrue);
      expect(
          e.adaylar('mbappe').firstWhere((a) => a.idx == m.idx).neden, 'Alındı');
    });
  });

  group('SERBEST KADRO (Mac + Milli Gol)', () {
    test('CAPA: Messi 876 mac, CR7 146 milli gol', () {
      expect(
          repos.mac.oyuncular.firstWhere((o) => o.ad == 'Lionel Messi').deger,
          876);
      expect(
          repos.milligol.oyuncular
              .firstWhere((o) => o.ad == 'Cristiano Ronaldo')
              .deger,
          146);
    });

    test('milligol formasyonunda KALECI YOK', () {
      final e = SerbestKadroEngine(repos.milligol, milligolConfig,
          rng: Random(1));
      expect(e.acikMevkiler(0), isNot(contains('K')));
      // kaleci secimi motor tarafindan reddedilir
      final kaleci =
          repos.milligol.oyuncular.indexWhere((o) => o.poz == 'K');
      if (kaleci >= 0) expect(e.sec(kaleci), isFalse);
    });

    test('tam oyun simulasyonu x10 seed (mac): YUKSEK kazanir', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final e = SerbestKadroEngine(repos.mac, macConfig,
            rng: Random(seed + 300));
        var adim = 0;
        while (!e.bitti && adim++ < 50) {
          final acik = e.acikMevkiler(e.simdiSecen);
          final gecerli = <int>[];
          for (var i = 0; i < repos.mac.oyuncular.length && gecerli.length < 40; i++) {
            if (!e.alinan.contains(i) &&
                acik.contains(repos.mac.oyuncular[i].poz)) {
              gecerli.add(i);
            }
          }
          if (gecerli.isEmpty || rng.nextInt(8) == 0) {
            e.sureDoldu();
          } else {
            expect(e.sec(gecerli[rng.nextInt(gecerli.length)]), isTrue);
          }
        }
        expect(e.bitti, isTrue);
        final k = e.kazanan();
        if (k != null) expect(e.toplam(k), greaterThan(e.toplam(1 - k)));
      }
    });
  });

  group('KUPA DRAFTI', () {
    test('6 tur 6 FARKLI kulup; havuz disi red', () {
      final e = KupaDraftEngine(repos.kupa, rng: Random(2));
      expect(e.kulupSirasi.toSet().length, kupaTurSayisi);
      final disari = List.generate(repos.kupa.oyuncular.length, (i) => i)
          .firstWhere((i) => !e.kulup.havuz.contains(i));
      expect(e.sec(disari), isFalse);
    });

    test('tam oyun simulasyonu x10 seed: YUKSEK kupa kazanir', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final e = KupaDraftEngine(repos.kupa, rng: Random(seed + 400));
        var adim = 0;
        while (!e.bitti && adim++ < 50) {
          final acik = e.acikMevkiler(e.simdiSecen);
          final gecerli = e.kulup.havuz
              .where((i) =>
                  !e.alinan.contains(i) &&
                  acik.contains(repos.kupa.oyuncular[i].poz))
              .toList();
          if (gecerli.isEmpty || rng.nextInt(8) == 0) {
            e.sureDoldu();
          } else {
            expect(e.sec(gecerli[rng.nextInt(gecerli.length)]), isTrue);
          }
        }
        expect(e.bitti, isTrue);
        for (var s = 0; s < 2; s++) {
          expect(e.kadrolar[s].length + e.bosEtap[s], kupaTurSayisi);
        }
        final k = e.kazanan();
        if (k != null) expect(e.toplam(k), greaterThan(e.toplam(1 - k)));
      }
    });
  });

  group('BAYRAK YARISI', () {
    test('her turda gecerli en az 3 cevap var; ulke+kulup tekrari yok', () {
      for (var seed = 0; seed < 10; seed++) {
        final e = BayrakYarisiEngine(repos.boy, rng: Random(seed));
        expect(e.turlar.length, bayrakTurSayisi);
        expect(e.turlar.map((c) => c.ulke).toSet().length, bayrakTurSayisi);
        expect(e.turlar.map((c) => c.kulupIdx).toSet().length, bayrakTurSayisi);
        for (final c in e.turlar) {
          final uygun = repos.boy.kulupler[c.kulupIdx].havuz
              .where((i) => ulkeNorm(repos.boy.oyuncular[i].ulke) == c.ulke)
              .length;
          expect(uygun, greaterThanOrEqualTo(3),
              reason: 'seed $seed: ${c.ulke} cifti zayif');
        }
      }
    });

    test('kap → yanlis secim serbest ama tur kazandirmaz → pas → bos tur', () {
      final e = BayrakYarisiEngine(repos.boy, rng: Random(5));
      expect(e.kap(0), isTrue);
      expect(e.kap(0), isFalse); // zaten answer modunda
      expect(e.claimer, 0);
      // KURAL v2: yanlis ulkeden oyuncu dropdown'da SECILEBILIR (neden yok,
      // "Ülkesi farklı" ASLA gorunmez) ama cevapVer false doner → hak duser.
      final yanlis = e.kulup.havuz.firstWhere((i) =>
          ulkeNorm(repos.boy.oyuncular[i].ulke) != e.cift.ulke &&
          repos.boy.oyuncular[i].ad.length >= 4);
      final adaySonuc = e.adaylar(repos.boy.oyuncular[yanlis].ad.substring(0, 4));
      for (final a in adaySonuc) {
        expect(a.neden, isNot('Ülkesi farklı'), reason: 'ulke sizintisi!');
      }
      expect(e.cevapVer(yanlis), isFalse);
      expect(e.mod, BayrakMod.answer); // tur kapanmadi — UI hakDus cagirir
      // pas: hak digerine gecer
      expect(e.hakDus(), isTrue);
      expect(e.claimer, 1);
      // o da pas: tur bos kapanir
      expect(e.hakDus(), isFalse);
      expect(e.gecmis.last, -1);
      expect(e.mod, BayrakMod.done);
      // sonraki tur
      e.sonrakiTur();
      expect(e.tur, 1);
      expect(e.mod, BayrakMod.race);
    });

    test('dogru cevap turu alir; 5 tur sonunda kazanan dogru', () {
      final e = BayrakYarisiEngine(repos.boy, rng: Random(7));
      while (!e.bitti) {
        e.kap(0);
        final dogru = e.kulup.havuz.firstWhere((i) =>
            ulkeNorm(repos.boy.oyuncular[i].ulke) == e.cift.ulke &&
            !e.alinan.contains(i));
        expect(e.cevapVer(dogru), isTrue);
        e.sonrakiTur();
      }
      expect(e.skor[0], bayrakTurSayisi);
      expect(e.kazanan(), 0);
    });
  });

  group('KARIYER IKIZI', () {
    test('referans kurallari: ilk 600, 100+ lig maci, sari verisi var', () {
      for (var seed = 0; seed < 10; seed++) {
        final e = KariyerIkiziEngine(repos.ikiz, rng: Random(seed));
        expect(e.refIdx, lessThan(600));
        expect(e.ref.ligMac.reduce(max), greaterThanOrEqualTo(100));
        expect(e.ref.sari, greaterThanOrEqualTo(0));
        expect(e.sorular.length, ikizSoruSayisi);
        expect(e.sorular.map((s) => s.ad).toSet().length, ikizSoruSayisi);
      }
    });

    test('yakin olan puani alir; referans yazilamaz', () {
      final e = KariyerIkiziEngine(repos.ikiz, rng: Random(3));
      expect(e.sec(e.refIdx), isFalse);
      // hedefe gore iki farkli mesafede oyuncu bul
      final k = e.aktifSoru;
      int? yakin, uzak;
      num yakinD = 1e12, uzakD = -1;
      for (var i = 0; i < repos.ikiz.oyuncular.length; i++) {
        if (i == e.refIdx) continue;
        final v = k.deger(repos.ikiz.oyuncular[i]);
        if (v == null) continue;
        final d = (v - k.hedefSayi).abs();
        if (d < yakinD) {
          yakinD = d;
          yakin = i;
        }
        if (d > uzakD) {
          uzakD = d;
          uzak = i;
        }
      }
      if (yakin != null && uzak != null && yakinD != uzakD) {
        expect(e.sec(yakin), isTrue); // O1 yakin
        expect(e.sec(uzak), isTrue); // O2 uzak
        expect(e.soruKapandi, isTrue);
        expect(e.sonuclar.last.kazananS, 0);
        expect(e.skor[0], 1);
      }
    });

    test('tam mac simulasyonu x8 seed: 5 soru, skor tutarli', () {
      for (var seed = 0; seed < 8; seed++) {
        final rng = Random(seed);
        final e = KariyerIkiziEngine(repos.ikiz, rng: Random(seed + 700));
        while (!e.bitti) {
          if (rng.nextInt(6) == 0) {
            e.sureDoldu();
          } else {
            int i;
            do {
              i = rng.nextInt(repos.ikiz.oyuncular.length);
            } while (e.alinan.contains(i));
            expect(e.sec(i), isTrue);
          }
          if (e.soruKapandi) e.sonrakiSoru();
        }
        expect(e.sonuclar.length, ikizSoruSayisi);
        final puanlar = e.sonuclar.where((s) => s.kazananS != null).length;
        expect(e.skor[0] + e.skor[1], puanlar);
        final k = e.kazanan();
        if (k != null) expect(e.skor[k], greaterThan(e.skor[1 - k]));
      }
    });
  });
}
