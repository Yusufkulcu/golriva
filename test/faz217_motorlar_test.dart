import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/repos.dart';
import 'package:golriva/games/veto_drafti/engine.dart';
import 'package:golriva/games/yirmibir/engine.dart';
import 'test_repos.dart';

/// FAZ 2.17 motor testleri: Bonservis 21'i (blackjack kor av) +
/// Veto Drafti (kupa drafti + veto katmani).
void main() {
  late GolrivaRepos repos;

  setUpAll(() {
    repos = testRepos();
  });

  group('BONSERVIS 21\'I', () {
    test('seed determinizmi: ayni seed → ayni hedef + ayni ilk sira', () {
      for (var seed = 0; seed < 20; seed++) {
        final a = YirmibirEngine(repos.fee, rng: Random(seed));
        final b = YirmibirEngine(repos.fee, rng: Random(seed));
        expect(a.hedef, b.hedef);
        expect(a.sira, b.sira);
      }
    });

    test('hedef: top-6 toplaminin %8-45 araliginda tam onluk', () {
      final maxN = repos.fee.topDegerler[5];
      var lo = (0.08 * maxN / 10).ceil() * 10;
      var hi = (0.45 * maxN / 10).floor() * 10;
      if (lo < 10) lo = 10;
      if (hi < lo) hi = lo;
      for (var seed = 0; seed < 40; seed++) {
        final e = YirmibirEngine(repos.fee, rng: Random(seed));
        expect(e.hedef % 10, 0);
        expect(e.hedef, greaterThanOrEqualTo(lo));
        expect(e.hedef, lessThanOrEqualTo(hi));
      }
    });

    test('hedefi asan YANAR: mac ANINDA biter, diger taraf direkt kazanir',
        () {
      final e = YirmibirEngine(repos.fee, rng: Random(1));
      final s = e.sira;
      // s EN DEGERLI oyuncularla hedefi kasten asar (hedef ≤ %45 top-6,
      // yani top oyunculardan en cok 6 secim kesin asar); diger taraf
      // sirasi gelince DUR der.
      final pahalilar = List.generate(repos.fee.oyuncular.length, (x) => x)
        ..sort((a, b) => repos.fee.oyuncular[b]
            .deger
            .compareTo(repos.fee.oyuncular[a].deger));
      var i = 0;
      while (!e.yandi[s] && !e.bitti && i < pahalilar.length) {
        if (e.sira == s) {
          e.sec(pahalilar[i++]);
        } else {
          e.dur();
        }
      }
      expect(e.yandi[s], isTrue, reason: 'hedef ${e.hedef} asilamadi?');
      expect(e.durdu[s], isTrue);
      expect(e.toplam(s), greaterThan(e.hedef.toDouble()));
      // KULLANICI KARARI: yanma ani = mac sonu; solo devam YOK
      expect(e.bitti, isTrue);
      expect(e.kazanan(), 1 - s); // yanmayan direkt kazanir
      // bitmis macta hicbir hamle islemez
      expect(e.sec(pahalilar[i]), isFalse);
    });

    test('DUR: duran bir daha oynayamaz, diger solo devam eder', () {
      final e = YirmibirEngine(repos.fee, rng: Random(2));
      final s = e.sira;
      e.dur();
      expect(e.durdu[s], isTrue);
      expect(e.bitti, isFalse);
      expect(e.sira, 1 - s); // sira digerine gecti
      // diger secim yapinca sira ONDA KALIR (solo devam)
      final aday = List.generate(repos.fee.oyuncular.length, (x) => x)
          .firstWhere((x) => !e.alinan.contains(x));
      expect(e.sec(aday), isTrue);
      if (!e.bitti) expect(e.sira, 1 - s);
      // o da durunca mac biter
      if (!e.bitti) {
        e.dur();
        expect(e.bitti, isTrue);
      }
    });

    test('emniyet tavani: $yirmibirMaxSecim secimde otomatik DUR', () {
      // dusuk degerli oyuncularla asla yanmadan tavana vur
      final e = YirmibirEngine(repos.fee, rng: Random(3));
      final s = e.sira;
      // digerini hemen kapat ki sira hep s'de kalsin
      // (once s secmeli — sira s'de; s bir secim yapip sirayi verir)
      final ucuzlar = List.generate(repos.fee.oyuncular.length, (x) => x)
        ..sort((a, b) => repos.fee.oyuncular[a]
            .deger
            .compareTo(repos.fee.oyuncular[b].deger));
      var c = 0;
      while (!e.bitti &&
          !e.durdu[s] &&
          e.secimler[s].length < yirmibirMaxSecim &&
          c < ucuzlar.length) {
        if (e.sira == s) {
          e.sec(ucuzlar[c++]);
        } else {
          e.dur(); // diger taraf kapansin
        }
      }
      // ya tavana vurdu ya yandi — iki durumda da durmus olmali
      expect(e.durdu[s], isTrue);
      if (!e.yandi[s]) {
        expect(e.secimler[s].length, yirmibirMaxSecim);
      }
    });

    test('kazanan kurali: yanan direkt kaybeder; saglamlarda mutlak yakin',
        () {
      final e = YirmibirEngine(repos.fee, rng: Random(4));
      // yanma asimetrisi (yeni kuralda ikisi birden yanamaz):
      e.yandi[0] = true;
      e.yandi[1] = false;
      expect(e.kazanan(), 1);
      e.yandi[0] = false;
      e.yandi[1] = true;
      expect(e.kazanan(), 0);
      // ikisi de saglam ve secim yok → fark esit → berabere
      e.yandi[1] = false;
      expect(e.kazanan(), isNull);
    });

    test('adaylar: kor meta (deger sizmaz motor katindan), Alindi nedeni', () {
      final e = YirmibirEngine(repos.fee, rng: Random(5));
      expect(e.adaylar('mb'), isEmpty); // min 3 harf
      final sonuc = e.adaylar('mbappe');
      expect(sonuc, isNotEmpty);
      final m = sonuc.firstWhere(
          (a) => repos.fee.oyuncular[a.idx].ad == 'Kylian Mbappé');
      expect(m.neden, isNull);
      expect(e.sec(m.idx), isTrue);
      expect(e.adaylar('mbappe').firstWhere((a) => a.idx == m.idx).neden,
          'Alındı');
      // ayni oyuncu ikinci kez secilemez
      expect(e.sec(m.idx), isFalse);
    });

    test('tam mac simulasyonu x15 seed: invaryantlar', () {
      for (var seed = 0; seed < 15; seed++) {
        final rng = Random(seed);
        final e = YirmibirEngine(repos.fee, rng: Random(seed + 500));
        var adim = 0;
        while (!e.bitti && adim++ < 60) {
          final s = e.sira;
          expect(e.durdu[s], isFalse,
              reason: 'sira duran oyuncuda olamaz (seed $seed)');
          if (rng.nextInt(4) == 0) {
            e.dur();
          } else {
            int i;
            do {
              i = rng.nextInt(repos.fee.oyuncular.length);
            } while (e.alinan.contains(i));
            expect(e.sec(i), isTrue);
          }
        }
        expect(e.bitti, isTrue, reason: 'seed $seed bitmedi');
        for (var s = 0; s < 2; s++) {
          expect(e.secimler[s].length, lessThanOrEqualTo(yirmibirMaxSecim));
          // yandi ⇔ toplam > hedef
          expect(e.yandi[s], e.toplam(s) > e.hedef);
        }
        if (e.yandi[0] || e.yandi[1]) {
          // yanma ani = mac sonu: IKISI BIRDEN YANAMAZ, yanmayan kazanir
          expect(e.yandi[0] && e.yandi[1], isFalse);
          expect(e.kazanan(), e.yandi[0] ? 1 : 0);
        } else {
          // kimse yanmadi → ikisi de DUR demis olmali
          expect(e.durdu[0] && e.durdu[1], isTrue);
          final k = e.kazanan();
          if (k != null) expect(e.fark(k), lessThan(e.fark(1 - k)));
        }
      }
    });
  });

  group('VETO DRAFTI', () {
    test('seed determinizmi: ayni seed → ayni kulup sirasi', () {
      for (var seed = 0; seed < 20; seed++) {
        final a = VetoDraftEngine(repos.kupa, rng: Random(seed));
        final b = VetoDraftEngine(repos.kupa, rng: Random(seed));
        expect(a.kulupSirasi, b.kulupSirasi);
      }
    });

    test('6 tur 6 FARKLI kulup; snake oncelik degisimi', () {
      final e = VetoDraftEngine(repos.kupa, rng: Random(2));
      expect(e.kulupSirasi.toSet().length, vetoTurSayisi);
      expect(e.firstPicker(0), 0);
      expect(e.firstPicker(1), 1);
      expect(e.firstPicker(2), 0);
    });

    int? gecerliSec(VetoDraftEngine e) {
      final acik = e.acikMevkiler(e.simdiSecen);
      for (final i in e.kulup.havuz) {
        if (!e.alinan.contains(i) &&
            acik.contains(repos.kupa.oyuncular[i].poz)) {
          return i;
        }
      }
      return null;
    }

    test('veto akisi: sec → pencere → vetoYap yakar, ayni secen tekrar', () {
      final e = VetoDraftEngine(repos.kupa, rng: Random(3));
      final secen = e.simdiSecen;
      final idx = gecerliSec(e)!;
      expect(e.sec(idx), isTrue);
      // rakipte 2 hak var → pencere acildi
      expect(e.asama, VetoAsama.veto);
      expect(e.adayIdx, idx);
      expect(e.aktor, 1 - secen); // karar rakibin
      // pencerede yeni secim / sureDoldu ISLEMEZ
      expect(e.sec(idx), isFalse);
      final oncekiBos = e.bosEtap[secen];
      e.sureDoldu();
      expect(e.bosEtap[secen], oncekiBos); // veto asamasinda etki yok
      // VETO: yakildi, hak dustu, ayni secen yeniden secer
      expect(e.vetoYap(), isTrue);
      expect(e.vetoHak[1 - secen], vetoHakSayisi - 1);
      expect(e.alinan.contains(idx), isTrue); // yakildi
      expect(e.kadrolar[secen], isEmpty); // kadroya girmedi
      expect(e.asama, VetoAsama.secim);
      expect(e.simdiSecen, secen); // sira ILERLEMEDI
      // yakilan yeniden SECILEMEZ
      expect(e.sec(idx), isFalse);
      final aday = e
          .adaylar(repos.kupa.oyuncular[idx].normAd.substring(0, 3))
          .where((a) => a.idx == idx);
      if (aday.isNotEmpty) expect(aday.first.neden, 'Alındı');
    });

    test('gec: bekleyen secim kesinlesir, tur ilerler', () {
      final e = VetoDraftEngine(repos.kupa, rng: Random(4));
      final secen = e.simdiSecen;
      final idx = gecerliSec(e)!;
      expect(e.sec(idx), isTrue);
      expect(e.gec(), isTrue);
      expect(e.kadrolar[secen].length, 1);
      expect(e.kadrolar[secen].first.idx, idx);
      expect(e.asama, VetoAsama.secim);
      expect(e.simdiSecen, 1 - secen); // faz ilerledi
      // pencere disinda veto/gec ISLEMEZ
      expect(e.vetoYap(), isFalse);
      expect(e.gec(), isFalse);
    });

    test('veto hakki bitince secimler pencereye ugramadan kesinlesir', () {
      final e = VetoDraftEngine(repos.kupa, rng: Random(5));
      // iki tarafin da hakkini manuel tuket (motor state'i uzerinden)
      e.vetoHak[0] = 0;
      e.vetoHak[1] = 0;
      final secen = e.simdiSecen;
      final idx = gecerliSec(e)!;
      expect(e.sec(idx), isTrue);
      expect(e.asama, VetoAsama.secim); // pencere ACILMADI
      expect(e.kadrolar[secen].length, 1); // aninda kesinlesti
    });

    test('sureDoldu (secim asamasi): etap bos gecer', () {
      final e = VetoDraftEngine(repos.kupa, rng: Random(6));
      final secen = e.simdiSecen;
      e.sureDoldu();
      expect(e.bosEtap[secen], 1);
      expect(e.simdiSecen, 1 - secen);
    });

    test('tam draft simulasyonu x12 seed: invaryantlar', () {
      for (var seed = 0; seed < 12; seed++) {
        final rng = Random(seed);
        final e = VetoDraftEngine(repos.kupa, rng: Random(seed + 600));
        var adim = 0;
        while (!e.bitti && adim++ < 200) {
          if (e.asama == VetoAsama.veto) {
            // vetocu rastgele karar verir
            if (rng.nextInt(2) == 0 && e.vetoHak[e.vetocu] > 0) {
              expect(e.vetoYap(), isTrue);
            } else {
              expect(e.gec(), isTrue);
            }
            continue;
          }
          final i = gecerliSec(e);
          if (i == null || rng.nextInt(8) == 0) {
            e.sureDoldu();
          } else {
            expect(e.sec(i), isTrue);
          }
        }
        expect(e.bitti, isTrue, reason: 'seed $seed bitmedi (adim $adim)');
        var yakilan = 0;
        for (var s = 0; s < 2; s++) {
          expect(e.kadrolar[s].length + e.bosEtap[s], vetoTurSayisi,
              reason: 'seed $seed taraf $s etap sayisi');
          expect(e.vetoHak[s], greaterThanOrEqualTo(0));
          yakilan += vetoHakSayisi - e.vetoHak[s];
          // formasyon asilmadi
          final sayim = <String, int>{};
          for (final p in e.kadrolar[s]) {
            sayim[p.poz] = (sayim[p.poz] ?? 0) + 1;
            expect(e.alinan.contains(p.idx), isTrue);
          }
          for (final z in vetoFormation.keys) {
            expect(sayim[z] ?? 0, lessThanOrEqualTo(vetoFormation[z]!));
          }
        }
        // alinan = kadrolar + yakilanlar
        expect(e.alinan.length,
            e.kadrolar[0].length + e.kadrolar[1].length + yakilan);
        // kadrolar kesisim bos (ayni oyuncu iki kadroda olamaz)
        final s0 = e.kadrolar[0].map((p) => p.idx).toSet();
        final s1 = e.kadrolar[1].map((p) => p.idx).toSet();
        expect(s0.intersection(s1), isEmpty);
        final k = e.kazanan();
        if (k != null) expect(e.toplam(k), greaterThan(e.toplam(1 - k)));
      }
    });
  });
}
