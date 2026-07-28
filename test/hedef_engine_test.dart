import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/hedef_repository.dart';
import 'package:golriva/games/hedefi_tuttur/engine.dart';

void main() {
  late HedefRepository repo;

  setUpAll(() {
    final raw = File('assets/data/hedef_data.json').readAsStringSync();
    repo = HedefRepository.fromJsonString(raw);
  });

  test('CAPA: Messi/CR7 degerleri (veri asla uydurulmaz ilkesi)', () {
    final messi = repo.oyuncular.firstWhere((o) => o.ad == 'Lionel Messi');
    expect(messi.degerler[0], 163); // SL mac
    expect(messi.degerler[1], 129); // SL gol
    expect(messi.degerler[4], 520); // LaLiga mac
    expect(messi.degerler[5], 474); // LaLiga gol
    final cr7 = repo.oyuncular.firstWhere((o) => o.ad == 'Cristiano Ronaldo');
    expect(cr7.degerler[0], 183);
    expect(cr7.degerler[1], 140);
    expect(cr7.degerler[2], 236); // PL mac
    expect(cr7.degerler[3], 103); // PL gol
  });

  test('14 kategori var; govde/tur ayrimi dogru (MAÇI/GOLÜ iri gosterim)', () {
    expect(repo.kategoriler.length, 14);
    final sl = repo.kategoriler[1];
    expect(sl.ad, 'Şampiyonlar Ligi GOLÜ');
    expect(sl.govde, 'Şampiyonlar Ligi');
    expect(sl.tur, 'GOLÜ');
  });

  test('HEDEF FORMULU v2: her kategori x her N icin erisilebilir + tam onluk',
      () {
    // "Bundesliga 900 gol" faciasi regresyon testi: hedef ASLA top-N'i asamaz.
    for (var ci = 0; ci < repo.kategoriler.length; ci++) {
      for (var n = 4; n <= 7; n++) {
        for (var seed = 0; seed < 30; seed++) {
          final e = HedefiTutturEngine(repo,
              rng: Random(seed), sabitKatIdx: ci, sabitN: n);
          final maxN = repo.topDegerler[ci][n - 1];
          expect(e.hedef % 10, 0,
              reason: '${repo.kategoriler[ci].ad} N=$n: hedef tam onluk degil');
          expect(e.hedef, lessThanOrEqualTo(maxN),
              reason: '${repo.kategoriler[ci].ad} N=$n: hedef ulasilamaz!');
          expect(e.hedef, greaterThanOrEqualTo((0.40 * maxN / 10).ceil() * 10),
              reason: '${repo.kategoriler[ci].ad} N=$n: hedef cok kolay');
          expect(e.hedef, lessThanOrEqualTo((0.65 * maxN / 10).floor() * 10));
        }
      }
    }
  });

  test('arama: min 3 harf, kor meta, kap-kac "Alındı"', () {
    final e = HedefiTutturEngine(repo, rng: Random(1));
    expect(e.adaylar('me'), isEmpty); // 2 harf yasak
    final sonuc = e.adaylar('messi');
    expect(sonuc, isNotEmpty);
    final messiIdx =
        sonuc.firstWhere((a) => repo.oyuncular[a.idx].ad == 'Lionel Messi').idx;
    expect(e.sec(messiIdx), isTrue);
    final tekrar = e.adaylar('messi')
        .firstWhere((a) => a.idx == messiIdx);
    expect(tekrar.neden, 'Alındı'); // sessiz engel yasak — sebep gorunur
    expect(e.sec(messiIdx), isFalse); // motor da reddeder
  });

  test('TR arama: "gundogan" → İlkay Gündoğan bulunur', () {
    final e = HedefiTutturEngine(repo, rng: Random(2));
    final sonuc = e.adaylar('gundogan');
    expect(sonuc.map((a) => repo.oyuncular[a.idx].ad),
        contains('İlkay Gündoğan'));
  });

  test('tam oyun simulasyonu x20 seed: invaryantlar', () {
    for (var seed = 0; seed < 20; seed++) {
      final rng = Random(seed);
      final e = HedefiTutturEngine(repo, rng: Random(seed + 500));
      var adimSayisi = 0;
      while (!e.bitti && adimSayisi < 100) {
        adimSayisi++;
        if (rng.nextInt(10) == 0) {
          e.sureDoldu(); // %10 sure asimi
        } else {
          // rastgele gecerli oyuncu sec
          int idx;
          do {
            idx = rng.nextInt(repo.oyuncular.length);
          } while (e.alinan.contains(idx));
          expect(e.sec(idx), isTrue);
        }
      }
      expect(e.bitti, isTrue, reason: 'seed $seed: oyun bitmedi');
      for (var s = 0; s < 2; s++) {
        expect(e.secimler[s].length + e.yanan[s], e.kadroN,
            reason: 'seed $seed: oyuncu $s hak sayisi tutmuyor');
        final beklenen =
            e.secimler[s].fold<int>(0, (a, i) => a + e.deger(i));
        expect(e.toplam(s), beklenen);
      }
      final k = e.kazanan();
      if (k != null) {
        expect(e.fark(k), lessThan(e.fark(1 - k)));
      } else {
        expect(e.fark(0), e.fark(1));
      }
      // acilis sirasi: toplam secim kadar hucre, satir-satir sirali
      final sira = e.acilisSirasi();
      expect(sira.length, e.secimler[0].length + e.secimler[1].length);
      for (var i = 1; i < sira.length; i++) {
        expect(sira[i].$2 >= sira[i - 1].$2, isTrue,
            reason: 'acilis satir sirasi bozuk');
      }
    }
  });

  test('bitti sonrasi sec/sureDoldu etkisiz', () {
    final e = HedefiTutturEngine(repo, rng: Random(7), sabitN: 4);
    var i = 0;
    while (!e.bitti) {
      e.sureDoldu();
      i++;
      expect(i, lessThan(20));
    }
    final oncekiYanan = [...e.yanan];
    e.sureDoldu();
    expect(e.sec(0), isFalse);
    expect(e.yanan, oncekiYanan);
  });
}
