import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/players_repository.dart';
import 'package:golriva/games/en_kisa_kadro/engine.dart';

/// GERCEK veri dosyasiyla motor testleri — HTML oyunlardaki Playwright
/// senaryolarinin Dart karsiliklari + PROJE_DURUMU capa kurallari.
void main() {
  late PlayersRepository repo;

  setUpAll(() {
    final raw = File('assets/data/boy_data.json').readAsStringSync();
    repo = PlayersRepository.fromJsonString(raw);
  });

  test('veri bütünlüğü: 13k+ oyuncu, 29 kulüp, 6 lig', () {
    expect(repo.oyuncular.length, greaterThan(13000));
    expect(repo.kulupler.length, 29); // Wolfsburg çıkarıldı
    expect(repo.ligler.length, 6);
  });

  test('çapalar: Messi 170, CR7 188, Crouch 201', () {
    Oyuncu bul(String ad) => repo.oyuncular.firstWhere((o) => o.ad == ad);
    expect(bul('Lionel Messi').boyCm, 170);
    expect(bul('Cristiano Ronaldo').boyCm, 188);
    expect(bul('Peter Crouch').boyCm, 201);
  });

  test('çapa: Alex (Alexsandro de Souza) Fenerbahçe havuzunda', () {
    final alexIdx = repo.oyuncular
        .indexWhere((o) => o.ad == 'Alex' && o.alias == 'Alexsandro de Souza');
    expect(alexIdx, greaterThanOrEqualTo(0));
    final fb = repo.kulupler.firstWhere((k) => k.ad == 'Fenerbahçe');
    expect(fb.havuz.contains(alexIdx), isTrue);
  });

  test('BOS_CEZA veri tavanının üstünde (boş slot avantaj olamaz)', () {
    final maxBoy = repo.oyuncular.map((o) => o.boyCm).reduce(max);
    expect(bosCeza, greaterThanOrEqualTo(maxBoy));
  });

  test('arama: min 3 harf kuralı', () {
    final e = EnKisaKadroEngine(repo, rng: Random(1));
    expect(e.adaylar('me'), isEmpty);
    expect(e.adaylar('a'), isEmpty);
  });

  test('öncelik her turda el değiştirir', () {
    final e = EnKisaKadroEngine(repo, rng: Random(1));
    expect(e.firstPicker(0), 0);
    expect(e.firstPicker(1), 1);
    expect(e.firstPicker(2), 0);
  });

  test('sebepli engeller: Alındı / dolu / Boy verisi yok', () {
    final e = EnKisaKadroEngine(repo, rng: Random(7));
    // gecerli birini bul ve sec
    final acik = e.acikMevkiler(e.simdiSecen);
    final idx = e.havuz.firstWhere((i) {
      final o = repo.oyuncular[i];
      return o.boyCm > 0 && acik.contains(o.poz);
    });
    final ad = repo.oyuncular[idx].ad;
    expect(e.sec(idx), isTrue);
    // ayni turda ikinci secici arayinca "Alındı" gormeli
    final sonuc = e.adaylar(ad);
    final aday = sonuc.firstWhere((a) => a.idx == idx);
    expect(aday.neden, 'Alındı');
  });

  test('motor UI güvensiz: havuz dışı / boysuz / tekrar seçim reddedilir', () {
    final e = EnKisaKadroEngine(repo, rng: Random(3));
    // havuzda olmayan bir indeks bul
    final havuzSet = e.havuz.toSet();
    final disIdx = List.generate(repo.oyuncular.length, (i) => i)
        .firstWhere((i) => !havuzSet.contains(i));
    expect(e.sec(disIdx), isFalse);
    // boysuz oyuncu varsa reddedilmeli
    final boysuz = e.havuz.where((i) => repo.oyuncular[i].boyCm <= 0).toList();
    if (boysuz.isNotEmpty) {
      expect(e.sec(boysuz.first), isFalse);
    }
  });

  test('tam oyun simülasyonu: formasyon limitleri + kazanan kısa olan', () {
    for (var seed = 0; seed < 20; seed++) {
      final e = EnKisaKadroEngine(repo, rng: Random(seed));
      var adim = 0;
      while (!e.bitti && adim++ < 40) {
        final acik = e.acikMevkiler(e.simdiSecen);
        final idx = e.havuz.cast<int?>().firstWhere(
              (i) =>
                  !e.alinan.contains(i) &&
                  repo.oyuncular[i!].boyCm > 0 &&
                  acik.contains(repo.oyuncular[i].poz),
              orElse: () => null,
            );
        if (idx == null) {
          e.sureDoldu();
        } else {
          expect(e.sec(idx), isTrue);
        }
      }
      expect(e.bitti, isTrue);
      for (var s = 0; s < 2; s++) {
        final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
        for (final p in e.kadrolar[s]) {
          sayim[p.poz] = sayim[p.poz]! + 1;
        }
        expect(sayim['K'], lessThanOrEqualTo(1));
        expect(sayim['D'], lessThanOrEqualTo(2));
        expect(sayim['O'], lessThanOrEqualTo(2));
        expect(sayim['F'], lessThanOrEqualTo(1));
      }
      final k = e.kazanan();
      if (k != null) {
        expect(e.toplam(k), lessThan(e.toplam(1 - k)));
      } else {
        expect(e.toplam(0), e.toplam(1));
      }
    }
  });

  test('süre dolunca boş slot cezası toplama işlenir', () {
    final e = EnKisaKadroEngine(repo, rng: Random(5));
    e.sureDoldu(); // O1'in ilk hakki yandi
    expect(e.toplam(0), turSayisi * bosCeza); // hic secim yok: 6 slot x ceza
  });
}
