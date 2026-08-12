import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/repos.dart';
import 'package:golriva/games/daha_mi_yuksek/engine.dart';
import 'package:golriva/games/kim_bu/engine.dart';
import 'package:golriva/games/ortak_kulup/engine.dart';
import 'package:golriva/games/sirala_bakalim/engine.dart';
import 'package:golriva/games/sl_gecesi/engine.dart';
import 'test_repos.dart';

/// FAZ 2.18 motor testleri: Kim Bu? · Daha mı Yüksek? · Sırala Bakalım ·
/// Ortak Kulüp Avı · ŞL Gecesi.
void main() {
  late GolrivaRepos repos;

  setUpAll(() {
    repos = testRepos();
  });

  group('KIM BU?', () {
    test('seed determinizmi + $kimBuTurSayisi FARKLI temiz gizem + kulup', () {
      for (var seed = 0; seed < 15; seed++) {
        final a = KimBuEngine(repos.fee,
            kulupRepo: repos.boy, rng: Random(seed));
        final b = KimBuEngine(repos.fee,
            kulupRepo: repos.boy, rng: Random(seed));
        expect(a.gizemler, b.gizemler);
        expect(a.gizemKulupleri, b.gizemKulupleri); // kulup ipucu da ayni
        expect(a.gizemler.toSet().length, kimBuTurSayisi);
        for (final g in a.gizemler) {
          final o = repos.fee.oyuncular[g];
          expect(o.deger, greaterThan(0));
          expect(o.dogumYili, greaterThan(0));
          expect(o.ulke, isNotEmpty);
        }
      }
    });

    test('kulup ipucu: bulunursa 8, yoksa 7 ipucu; liste tutarli', () {
      for (var seed = 0; seed < 10; seed++) {
        final e = KimBuEngine(repos.fee,
            kulupRepo: repos.boy, rng: Random(seed));
        for (var t = 0; t < kimBuTurSayisi; t++) {
          final n = e.tumIpuclari().length;
          expect(n, anyOf(7, 8));
          final kulupVar = e.tumIpuclari()
              .any((ip) => ip.$1 == 'OYNADIĞI KULÜP');
          expect(kulupVar, e.gizemKulupleri[e.tur] != null);
          // sonraki tura gecmek icin turu kapat (dogru tahmin)
          e.tahmin(e.gizemler[e.tur]);
          if (e.bitti) break;
        }
      }
    });

    test('ipucu ac: soz rakibe gecer, puan azalir; ipucu tavani', () {
      final e = KimBuEngine(repos.fee,
          kulupRepo: repos.boy, rng: Random(1));
      final n = e.ipucuSayisi; // 7 ya da 8
      expect(e.acik, 1);
      expect(e.turPuani, n);
      final ilkAktor = e.aktor;
      expect(e.ipucuAc(), isTrue);
      expect(e.acik, 2);
      expect(e.turPuani, n - 1);
      expect(e.aktor, 1 - ilkAktor);
      while (e.ipucuKaldi) {
        expect(e.ipucuAc(), isTrue);
      }
      expect(e.acik, n);
      expect(e.turPuani, 1);
      expect(e.ipucuAc(), isFalse); // tavan
      expect(e.acikIpuclari().length, n);
    });

    test('dogru tahmin turu kapatir ve erken bilene cok puan yazar', () {
      final e = KimBuEngine(repos.fee,
          kulupRepo: repos.boy, rng: Random(2));
      final tahminci = e.aktor;
      final beklenen = e.turPuani; // 1 ipucuyla: ipucu sayisi kadar
      expect(e.tahmin(e.gizemler[0]), isTrue);
      expect(e.skor[tahminci], beklenen);
      expect(e.tur, 1); // sonraki tura gecti
      expect(e.acik, 1);
      expect(e.turKazanani, [tahminci]);
    });

    test('yanlis tahmin kilitler; rakip solo; ikisi de yanlissa puansiz',
        () {
      final e = KimBuEngine(repos.fee, rng: Random(3));
      final ilk = e.aktor;
      // gizem OLMAYAN bir oyuncu bul
      final yanlis = List.generate(repos.fee.oyuncular.length, (i) => i)
          .firstWhere((i) => i != e.gizemler[0]);
      expect(e.tahmin(yanlis), isFalse);
      expect(e.kilitli[ilk], isTrue);
      expect(e.aktor, 1 - ilk);
      // kilitliyken rakip ipucu acsa soz onda kalir (solo)
      expect(e.ipucuAc(), isTrue);
      expect(e.aktor, 1 - ilk);
      // rakip de yanilirsa tur puansiz kapanir
      final yanlis2 = List.generate(repos.fee.oyuncular.length, (i) => i)
          .firstWhere((i) => i != e.gizemler[0] && i != yanlis);
      expect(e.tahmin(yanlis2), isFalse);
      expect(e.tur, 1);
      expect(e.turKazanani, [null]);
      expect(e.skor, [0, 0]);
      expect(e.kilitli, [false, false]); // yeni turda temiz
    });

    test('sure dolumu: ipucu varsa acar, yoksa pas=kilit', () {
      final e = KimBuEngine(repos.fee, rng: Random(4));
      e.sureDoldu();
      expect(e.acik, 2); // ipucu acildi
      while (e.ipucuKaldi) {
        e.ipucuAc();
      }
      final aktor = e.aktor;
      e.sureDoldu(); // pas
      expect(e.kilitli[aktor], isTrue);
      e.sureDoldu(); // rakip de pas → tur kapanir
      expect(e.tur, 1);
      expect(e.turKazanani, [null]);
    });

    test('tam mac simulasyonu x10 seed: skor tutarliligi', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final e = KimBuEngine(repos.fee, rng: Random(seed + 800));
        var adim = 0;
        while (!e.bitti && adim++ < 300) {
          final z = rng.nextInt(10);
          if (z < 4 && e.ipucuKaldi) {
            e.ipucuAc();
          } else if (z < 6) {
            e.tahmin(e.gizemler[e.tur]); // dogru
          } else if (z < 9) {
            final y = rng.nextInt(repos.fee.oyuncular.length);
            if (y != e.gizemler[e.tur]) e.tahmin(y);
          } else {
            e.sureDoldu();
          }
        }
        expect(e.bitti, isTrue, reason: 'seed $seed bitmedi');
        expect(e.turKazanani.length, kimBuTurSayisi);
        expect(e.skor[0] + e.skor[1], greaterThanOrEqualTo(0));
        final k = e.kazanan();
        if (k != null) expect(e.skor[k], greaterThan(e.skor[1 - k]));
      }
    });
  });

  group('DAHA MI YUKSEK?', () {
    test('seed determinizmi + her metrik tam 2 kez + gecerli sorular', () {
      for (var seed = 0; seed < 10; seed++) {
        final a = DahaMiYuksekEngine(repos, rng: Random(seed));
        final b = DahaMiYuksekEngine(repos, rng: Random(seed));
        expect(a.sorular.length, dahaTurSayisi);
        final sayim = <String, int>{};
        for (var i = 0; i < dahaTurSayisi; i++) {
          expect(a.sorular[i].metrikAd, b.sorular[i].metrikAd);
          expect(a.sorular[i].solAd, b.sorular[i].solAd);
          expect(a.sorular[i].sagAd, b.sorular[i].sagAd);
          expect(a.sorular[i].solDeger,
              isNot(equals(a.sorular[i].sagDeger)));
          expect(a.sorular[i].solAd, isNot(equals(a.sorular[i].sagAd)));
          sayim[a.sorular[i].metrikAd] =
              (sayim[a.sorular[i].metrikAd] ?? 0) + 1;
        }
        expect(sayim.values.toSet(), {2}); // 5 metrik x 2
      }
    });

    test('v2 es zamanli: iki taraf AYNI soruyu cevaplar, ikisi bitince ilerler',
        () {
      final e = DahaMiYuksekEngine(repos, rng: Random(1));
      final dogruCevap = e.soru.sagYuksek;
      // taraf 0 dogru cevapladi — tur ILERLEMEZ (taraf 1 bekleniyor)
      expect(e.cevap(0, yuksek: dogruCevap), isTrue);
      expect(e.tur, 0);
      expect(e.cevapladi(0), isTrue);
      expect(e.cevap(0, yuksek: dogruCevap), isNull); // mukerrer red
      // taraf 1 yanlis cevapladi: tur ILERLER
      expect(e.cevap(1, yuksek: !dogruCevap), isFalse);
      expect(e.tur, 1);
      expect(e.skor, [1, 0]);
      expect(e.sonuclar[0], [1, 0]);
      // sure dolumu: taraf 0 cevapsiz kapanir
      e.sureDoldu(0);
      expect(e.sonuclar[1][0], -1);
      expect(e.tur, 1); // taraf 1 hala cevaplamadi
    });

    test('tam mac simulasyonu x10 seed (es zamanli)', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final e = DahaMiYuksekEngine(repos, rng: Random(seed + 900));
        while (!e.bitti) {
          for (final s in [0, 1]) {
            if (e.bitti) break;
            if (rng.nextInt(8) == 0) {
              e.sureDoldu(s);
            } else {
              e.cevap(s, yuksek: rng.nextBool());
            }
          }
        }
        var s0 = 0, s1 = 0;
        for (var i = 0; i < dahaTurSayisi; i++) {
          expect(e.sonuclar[i][0], isNotNull);
          expect(e.sonuclar[i][1], isNotNull);
          if (e.sonuclar[i][0] == 1) s0++;
          if (e.sonuclar[i][1] == 1) s1++;
        }
        expect(e.skor, [s0, s1]);
        final k = e.kazanan();
        if (k != null) expect(e.skor[k], greaterThan(e.skor[1 - k]));
      }
    });
  });

  group('SIRALA BAKALIM', () {
    test('seed determinizmi + 4 farkli metrik + benzersiz degerler', () {
      for (var seed = 0; seed < 10; seed++) {
        final a = SiralaBakalimEngine(repos, rng: Random(seed));
        final b = SiralaBakalimEngine(repos, rng: Random(seed));
        expect(a.turlar.length, siralaTurSayisi);
        expect(a.turlar.map((t) => t.metrikAd).toSet().length,
            siralaTurSayisi);
        for (var i = 0; i < siralaTurSayisi; i++) {
          expect(a.turlar[i].oyuncuAdlari, b.turlar[i].oyuncuAdlari);
          expect(a.turlar[i].oyuncuAdlari.length, siralaOyuncuSayisi);
          expect(a.turlar[i].oyuncuAdlari.toSet().length,
              siralaOyuncuSayisi);
          expect(a.turlar[i].degerler.toSet().length, siralaOyuncuSayisi);
        }
      }
    });

    test('v2 es zamanli: iki taraf AYNI turu siralar, ikisi bitince ilerler',
        () {
      final e = SiralaBakalimEngine(repos, rng: Random(2));
      final dogru = e.aktifTur.dogruSira();
      expect(e.sirala(0, [0, 0, 1, 2]), isNull); // tekrarli
      expect(e.sirala(0, [0, 1]), isNull); // eksik
      // taraf 0 kusursuz gonderdi — tur ILERLEMEZ (taraf 1 bekleniyor)
      expect(e.sirala(0, dogru), siralaOyuncuSayisi + siralaBonus);
      expect(e.tur, 0);
      expect(e.gonderdi(0), isTrue);
      expect(e.sirala(0, dogru), isNull); // ikinci gonderim yok
      // taraf 1 tamamen ters gonderdi: 0 puan, tur ILERLER
      final ters = dogru.reversed.toList();
      expect(e.sirala(1, ters), 0);
      expect(e.tur, 1);
      expect(e.skor, [siralaOyuncuSayisi + siralaBonus, 0]);
      // sure dolumu: taraf 0 icin 0 puanla kapanir
      e.sureDoldu(0);
      expect(e.gonderdi(0), isTrue);
      expect(e.tur, 1); // taraf 1 hala gondermedi
    });

    test('tam mac simulasyonu x10 seed (es zamanli)', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final e = SiralaBakalimEngine(repos, rng: Random(seed + 1000));
        while (!e.bitti) {
          for (final s in [0, 1]) {
            if (e.bitti) break;
            if (rng.nextInt(6) == 0) {
              e.sureDoldu(s);
            } else {
              final dizi =
                  List<int>.generate(siralaOyuncuSayisi, (i) => i)
                    ..shuffle(rng);
              expect(e.sirala(s, dizi), isNotNull);
            }
          }
        }
        var s0 = 0, s1 = 0;
        for (var i = 0; i < siralaTurSayisi; i++) {
          expect(e.puanlar[i][0], isNotNull);
          expect(e.puanlar[i][1], isNotNull);
          s0 += e.puanlar[i][0]!;
          s1 += e.puanlar[i][1]!;
        }
        expect(e.skor, [s0, s1]);
      }
    });
  });

  group('ORTAK KULUP AVI', () {
    test('seed determinizmi + 5 gecerli cift (kesisim >= esik)', () {
      for (var seed = 0; seed < 10; seed++) {
        final a = OrtakKulupEngine(repos.boy, rng: Random(seed));
        final b = OrtakKulupEngine(repos.boy, rng: Random(seed));
        expect(a.ciftler, b.ciftler);
        expect(a.ciftler.length, ortakTurSayisi);
        expect(a.ciftler.toSet().length, ortakTurSayisi);
        for (final (i, j) in a.ciftler) {
          final ortak = repos.boy.kulupler[i].havuz
              .toSet()
              .intersection(repos.boy.kulupler[j].havuz.toSet());
          expect(ortak.length, greaterThanOrEqualTo(ortakMinKesisim),
              reason:
                  'seed $seed: ${repos.boy.kulupler[i].ad}+${repos.boy.kulupler[j].ad}');
        }
      }
    });

    test('dogru isim sozu devreder; yanlis isim turu RAKIBE verir', () {
      final e = OrtakKulupEngine(repos.boy, rng: Random(3));
      final sa = e.kulupA.havuz.toSet();
      final ortak = e.kulupB.havuz.where(sa.contains).toList();
      final ilk = e.aktor;
      expect(e.sec(ortak.first), isTrue);
      expect(e.aktor, 1 - ilk);
      expect(e.soylenen, {ortak.first});
      // ayni isim tekrar soylenemez
      expect(e.sec(ortak.first), isNull);
      // yanlis isim: iki kulupte birden olmayan biri
      final sb = e.kulupB.havuz.toSet();
      final yanlis = List.generate(repos.boy.oyuncular.length, (i) => i)
          .firstWhere((i) => !(sa.contains(i) && sb.contains(i)));
      final aktor = e.aktor;
      expect(e.sec(yanlis), isFalse);
      expect(e.skor[1 - aktor], 1); // turu rakip aldi
      expect(e.tur, 1);
      expect(e.soylenen, isEmpty); // yeni tur temiz
    });

    test('ortak havuzu kurutan turu alir', () {
      final e = OrtakKulupEngine(repos.boy, rng: Random(4));
      var adim = 0;
      while (e.tur == 0 && !e.bitti && adim++ < 100) {
        final sa = e.kulupA.havuz.toSet();
        final kalan = e.kulupB.havuz
            .where((i) => sa.contains(i) && !e.soylenen.contains(i))
            .toList();
        expect(kalan, isNotEmpty); // tur acikken hep secenek olmali
        final aktor = e.aktor;
        expect(e.sec(kalan.first), isTrue);
        if (e.tur == 1 || e.bitti) {
          // havuz kurudu — son soyleyen (aktor) turu aldi
          expect(e.turKazanani.first, aktor);
        }
      }
      expect(e.tur >= 1 || e.bitti, isTrue);
    });

    test('v2 YARIS modu: yanlis kilitler, ikisi de yanilirsa tur puansiz',
        () {
      final e = OrtakKulupEngine(repos.boy, rng: Random(7));
      final sa = e.kulupA.havuz.toSet(), sb = e.kulupB.havuz.toSet();
      final ortak = e.kulupA.havuz.where(sb.contains).toList();
      expect(e.dogruMu(ortak.first), isTrue);
      final yanlis = List.generate(repos.boy.oyuncular.length, (i) => i)
          .firstWhere((i) => !(sa.contains(i) && sb.contains(i)));
      expect(e.dogruMu(yanlis), isFalse);
      // taraf 0 yanildi: kilitlendi ama tur ACIK
      expect(e.yanlisla(0), isFalse);
      expect(e.kilitli[0], isTrue);
      expect(e.tur, 0);
      // taraf 1 de yanildi: tur PUANSIZ kapandi, kilitler temizlendi
      expect(e.yanlisla(1), isTrue);
      expect(e.tur, 1);
      expect(e.turKazanani, [null]);
      expect(e.skor, [0, 0]);
      expect(e.kilitli, [false, false]);
      // hakem karari: turu 1 aldi (ilk dogru yazan)
      final o2 = e.kulupA.havuz
          .where((i) => e.kulupB.havuz.contains(i))
          .first;
      e.turKapat(1, o2);
      expect(e.skor, [0, 1]);
      expect(e.turBulunan[1], o2);
      // puansiz turlarla BERABERE mumkun
      e.turKapat(0, null);
      e.turKapat(null, null);
      e.turKapat(null, null);
      expect(e.bitti, isTrue);
      expect(e.kazanan(), isNull); // 1-1, iki tur puansiz
    });

    test('sure dolumu turu rakibe verir; tam mac x8 seed', () {
      for (var seed = 0; seed < 8; seed++) {
        final rng = Random(seed);
        final e = OrtakKulupEngine(repos.boy, rng: Random(seed + 1100));
        var adim = 0;
        while (!e.bitti && adim++ < 400) {
          final z = rng.nextInt(6);
          if (z == 0) {
            e.sureDoldu();
          } else if (z == 1) {
            // kasitli yanlis
            final sa = e.kulupA.havuz.toSet(), sb = e.kulupB.havuz.toSet();
            final y = List.generate(repos.boy.oyuncular.length, (i) => i)
                .firstWhere(
                    (i) => !(sa.contains(i) && sb.contains(i)));
            e.sec(y);
          } else {
            final sa = e.kulupA.havuz.toSet();
            final kalan = e.kulupB.havuz
                .where(
                    (i) => sa.contains(i) && !e.soylenen.contains(i))
                .toList();
            if (kalan.isEmpty) {
              e.sureDoldu();
            } else {
              e.sec(kalan[rng.nextInt(kalan.length)]);
            }
          }
        }
        expect(e.bitti, isTrue, reason: 'seed $seed bitmedi');
        expect(e.skor[0] + e.skor[1], ortakTurSayisi);
        final k = e.kazanan();
        expect(k, isNotNull); // 5 turda beraberlik imkansiz
        expect(e.skor[k!], greaterThan(e.skor[1 - k]));
      }
    });
  });

  group('SL GECESI', () {
    test('seed determinizmi + 3 GOL + 2 ASIST', () {
      for (var seed = 0; seed < 15; seed++) {
        final a = SlGecesiEngine(repos.ikiz, rng: Random(seed));
        final b = SlGecesiEngine(repos.ikiz, rng: Random(seed));
        expect(a.kategoriler, b.kategoriler);
        expect(a.kategoriler.length, slTurSayisi);
        expect(
            a.kategoriler.where((k) => k == SlKategori.gol).length, 3);
        expect(
            a.kategoriler.where((k) => k == SlKategori.asist).length, 2);
      }
    });

    test('CAPA: CR7 140 SL golu, 50 SL asisti', () {
      final cr7 = repos.ikiz.oyuncular
          .firstWhere((o) => o.ad == 'Cristiano Ronaldo');
      expect(cr7.clGol, 140);
      expect(cr7.clAsist, 50);
    });

    test('sec kategoriye gore katki ekler; alinan tekrar secilemez', () {
      final e = SlGecesiEngine(repos.ikiz, rng: Random(2));
      final cr7 = repos.ikiz.oyuncular
          .indexWhere((o) => o.ad == 'Cristiano Ronaldo');
      final beklenen = e.katki(cr7);
      final secen = e.simdiSecen;
      expect(e.sec(cr7), isTrue);
      expect(e.toplam(secen), beklenen);
      expect(e.sec(cr7), isFalse); // alindi
      expect(
          e.adaylar('ronaldo').firstWhere((a) => a.idx == cr7).neden,
          'Alındı');
    });

    test('tam mac simulasyonu x10 seed: etap sayimi + kazanan', () {
      for (var seed = 0; seed < 10; seed++) {
        final rng = Random(seed);
        final e = SlGecesiEngine(repos.ikiz, rng: Random(seed + 1200));
        var adim = 0;
        while (!e.bitti && adim++ < 40) {
          if (rng.nextInt(8) == 0) {
            e.sureDoldu();
          } else {
            int i;
            do {
              i = rng.nextInt(repos.ikiz.oyuncular.length);
            } while (e.alinan.contains(i));
            expect(e.sec(i), isTrue);
          }
        }
        expect(e.bitti, isTrue);
        for (var s = 0; s < 2; s++) {
          expect(e.secimler[s].length + e.bosEtap[s], slTurSayisi);
        }
        final k = e.kazanan();
        if (k != null) expect(e.toplam(k), greaterThan(e.toplam(1 - k)));
      }
    });
  });
}
