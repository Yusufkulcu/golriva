import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/games/en_kisa_kadro/engine.dart';
import 'package:golriva/games/en_genc_kadro/engine.dart';
import 'package:golriva/games/hedefi_tuttur/engine.dart';
import 'package:golriva/games/kor_av/engine.dart';
import 'package:golriva/games/kupa_drafti/engine.dart';
import 'package:golriva/online/supabase_ayar.dart';
import 'package:golriva/screens/ana_iskelet.dart';
import 'test_repos.dart';

/// FAZ 2 cevrimdisi guvenlik testleri: Supabase yapilandirilmamis derlemede
/// (testler ve CI dahil) uygulama AGA CIKMAZ ve online arayuz gorunmez.
void main() {
  test('dart-define verilmeden Supabase yapilandirilmamis sayilir', () {
    expect(SupabaseAyar.yapilandirildi, isFalse);
  });

  testWidgets('cevrimdisi derlemede iskelet AGA CIKMADAN calisir',
      (tester) async {
    final repos = testRepos();
    await tester.pumpWidget(MaterialApp(home: AnaIskelet(repos: repos)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    // profil yok → misafir gorunumu; cevrimici degerler tire kalir
    expect(find.text('MİSAFİR'), findsOneWidget);
    expect(find.text('HIZLI DÜELLO'), findsOneWidget);
    // cevrimici sekme kibarca aciklama gosterir, istek atmaz
    // (artik tek aktif sekme kurulur — SIRALAMA'ya gecip bak)
    await tester.tap(find.text('SIRALAMA'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sıralama çevrimiçi bir özellik.'), findsOneWidget);
  });

  // FAZ 2.2: cevrimici oynanisin temeli — AYNI SEED, iki istemcide AYNI oyun.
  group('DETERMINIZM (online senkronun temeli)', () {
    test('ayni seed → ayni kurulum (tum motorlar)', () {
      final repos = testRepos();
      final an = DateTime(2026, 7, 30, 12); // mac baslangici (sunucudan gelir)
      for (final seed in [1, 42, 987654321]) {
        final k1 = EnKisaKadroEngine(repos.boy, rng: Random(seed));
        final k2 = EnKisaKadroEngine(repos.boy, rng: Random(seed));
        for (var t = 0; t < turSayisi; t++) {
          expect(k1.turlar[t].ligMi, k2.turlar[t].ligMi);
          expect(k1.turlar[t].index, k2.turlar[t].index);
        }
        final g1 = GencKadroEngine(repos.genc, rng: Random(seed), simdi: an);
        final g2 = GencKadroEngine(repos.genc, rng: Random(seed), simdi: an);
        for (var t = 0; t < gencTurSayisi; t++) {
          expect(g1.turlar[t], g2.turlar[t]);
        }
        final kd1 = KupaDraftEngine(repos.kupa, rng: Random(seed));
        final kd2 = KupaDraftEngine(repos.kupa, rng: Random(seed));
        expect(kd1.kulupSirasi, kd2.kulupSirasi);
        final h1 = HedefiTutturEngine(repos.hedef, rng: Random(seed));
        final h2 = HedefiTutturEngine(repos.hedef, rng: Random(seed));
        expect([h1.katIdx, h1.kadroN, h1.hedef, h1.sira],
            [h2.katIdx, h2.kadroN, h2.hedef, h2.sira]);
        final f1 = KorAvEngine(repos.fee, rng: Random(seed));
        final f2 = KorAvEngine(repos.fee, rng: Random(seed));
        expect([f1.kadroN, f1.hedef, f1.sira], [f2.kadroN, f2.hedef, f2.sira]);
      }
    });

    test('hamle aynasi: iki motor ayni akisla ayni sonuca ulasir', () {
      final repos = testRepos();
      final surucu = Random(7);
      final a = EnKisaKadroEngine(repos.boy, rng: Random(123));
      final b = EnKisaKadroEngine(repos.boy, rng: Random(123));
      var adim = 0;
      while (!a.bitti && adim++ < 50) {
        final acik = a.acikMevkiler(a.simdiSecen);
        final gecerli = a.havuz
            .where((i) =>
                !a.alinan.contains(i) &&
                acik.contains(repos.boy.oyuncular[i].poz) &&
                repos.boy.oyuncular[i].boyCm > 0)
            .toList();
        if (gecerli.isEmpty || surucu.nextInt(8) == 0) {
          a.sureDoldu();
          b.sureDoldu(); // "sure" hamlesi karsiya boyle tasinir
        } else {
          final i = gecerli[surucu.nextInt(gecerli.length)];
          expect(a.sec(i), isTrue);
          expect(b.sec(i), isTrue); // "sec" hamlesi karsiya boyle tasinir
        }
      }
      expect(b.bitti, isTrue);
      expect(a.toplam(0), b.toplam(0));
      expect(a.toplam(1), b.toplam(1));
      expect(a.kazanan(), b.kazanan());
    });
  });
}
