import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/repos.dart';
import 'package:golriva/games/bayrak_yarisi/screen.dart';
import 'package:golriva/games/en_genc_kadro/screen.dart';
import 'package:golriva/games/en_kisa_kadro/screen.dart';
import 'package:golriva/games/hedefi_tuttur/screen.dart';
import 'package:golriva/games/kariyer_ikizi/screen.dart';
import 'package:golriva/games/kor_av/screen.dart';
import 'package:golriva/games/kupa_drafti/screen.dart';
import 'package:golriva/games/serbest_kadro/engine.dart';
import 'package:golriva/games/serbest_kadro/screen.dart';
import 'package:golriva/screens/ana_iskelet.dart';
import 'package:golriva/screens/arkadasla_ekrani.dart';
import 'test_repos.dart';

/// Widget duman testleri — 4 sekmeli iskelet + 10 oyunun tamami.
/// (Tasarim seti golriva_ekranlar_v1.html: oyun listesi RANKED lobide YOK,
/// yalniz ARKADAŞLA OYNA ekraninda — rulet kurali.)
void main() {
  late GolrivaRepos repos;

  setUpAll(() {
    repos = testRepos();
  });

  Widget iskelet() => MaterialApp(home: AnaIskelet(repos: repos));
  Widget arkadasla() => MaterialApp(home: ArkadaslaEkrani(repos: repos));

  /// Ekran disinda kalan karta guvenli kaydirma (dis ListView uzerinden).
  Future<void> kartaGit(WidgetTester tester, String kart) async {
    final f = find.text(kart);
    if (f.evaluate().isEmpty) {
      await tester.dragUntilVisible(
          f, find.byType(ListView).first, const Offset(0, -100));
    }
    await tester.ensureVisible(f);
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Iskelet: 4 sekme + lobide HIZLI DÜELLO ve MASALAR',
      (tester) async {
    await tester.pumpWidget(iskelet());
    await tester.pump(const Duration(milliseconds: 100));
    for (final s in ['OYNA', 'SIRALAMA', 'DÜELLOLAR', 'PROFİL']) {
      expect(find.text(s), findsWidgets, reason: '$s sekmesi eksik');
    }
    expect(find.text('HIZLI DÜELLO'), findsOneWidget);
    expect(find.text('MASALAR'), findsOneWidget);
    expect(find.text('BO3 SERİ'), findsOneWidget);
    expect(find.text('ARKADAŞLA'), findsOneWidget);
    // tasarim kurali: ranked lobide oyun listesi OLMAZ (rulet secer)
    expect(find.text('EN KISA KADRO'), findsNothing);
  });

  testWidgets('Iskelet: ARKADAŞLA → oyun secim ekrani acilir', (tester) async {
    await tester.pumpWidget(iskelet());
    await tester.pump(const Duration(milliseconds: 100));
    await kartaGit(tester, 'ARKADAŞLA');
    await tester.tap(find.text('ARKADAŞLA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ArkadaslaEkrani), findsOneWidget);
    expect(find.text('RULET'), findsOneWidget);
  });

  testWidgets('Arkadasla: RULET + 10 oyun karti cizilir', (tester) async {
    await tester.pumpWidget(arkadasla());
    for (final ad in [
      'RULET',
      'EN KISA KADRO',
      'KUPA DRAFTI',
      'EN GENÇ KADRO',
      'BAYRAK YARIŞI',
      'HEDEFİ TUTTUR',
      'BONSERVİS AVI',
      'SARI KART AVI',
      'MAÇ REKORTMENLERİ',
      'MİLLİ GOL KRALLARI',
      'KARİYER İKİZİ',
    ]) {
      await kartaGit(tester, ad);
      expect(find.text(ad), findsOneWidget, reason: '$ad karti eksik');
    }
  });

  Future<void> gecisTesti(WidgetTester tester, String kart, Type ekran) async {
    await tester.pumpWidget(arkadasla());
    await kartaGit(tester, kart);
    await tester.tap(find.text(kart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ekran), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // timer temizligi
  }

  testWidgets('Gecis: EN KISA KADRO', (t) async {
    await gecisTesti(t, 'EN KISA KADRO', EnKisaKadroScreen);
  });
  testWidgets('Gecis: KUPA DRAFTI', (t) async {
    await gecisTesti(t, 'KUPA DRAFTI', KupaDraftiScreen);
  });
  testWidgets('Gecis: EN GENÇ KADRO', (t) async {
    await gecisTesti(t, 'EN GENÇ KADRO', EnGencKadroScreen);
  });
  testWidgets('Gecis: BAYRAK YARIŞI', (t) async {
    await gecisTesti(t, 'BAYRAK YARIŞI', BayrakYarisiScreen);
  });
  testWidgets('Gecis: HEDEFİ TUTTUR', (t) async {
    await gecisTesti(t, 'HEDEFİ TUTTUR', HedefiTutturScreen);
  });
  testWidgets('Gecis: BONSERVİS AVI', (t) async {
    await gecisTesti(t, 'BONSERVİS AVI', KorAvScreen);
  });
  testWidgets('Gecis: MAÇ REKORTMENLERİ', (t) async {
    await gecisTesti(t, 'MAÇ REKORTMENLERİ', SerbestKadroScreen);
  });
  testWidgets('Gecis: KARİYER İKİZİ', (t) async {
    await gecisTesti(t, 'KARİYER İKİZİ', KariyerIkiziScreen);
  });

  testWidgets('HEDEFİ TUTTUR: kor mekanik — secimden sonra deger "?" kalir',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: HedefiTutturScreen(repo: repos.hedef)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'messi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Lionel Messi').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('BAYRAK YARIŞI: KAP → cevap kutusu acilir', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: BayrakYarisiScreen(repo: repos.boy)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('KAP!'), findsNWidgets(2));
    await tester.tap(find.textContaining('KAP!').first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('PAS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SAHA GORUNUMU: bos mevkiler adlariyla sahada gorunur',
      (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: EnKisaKadroScreen(repo: repos.boy)));
    await tester.pump(const Duration(milliseconds: 50));
    // iki sahada da bos slotlar mevki ADIYLA gorunur (kullanici kurali)
    expect(find.text('Kaleci'), findsNWidgets(2));
    expect(find.text('Forvet'), findsNWidgets(2));
    expect(find.text('Defans'), findsNWidgets(4));
    expect(find.text('Orta'), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('SAHA GORUNUMU: milli golde kaleci sirasi YOK', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home:
            SerbestKadroScreen(repo: repos.milligol, config: milligolConfig)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Kaleci'), findsNothing);
    expect(find.text('Forvet'), findsNWidgets(4)); // 2 forvet x 2 saha
    await tester.pumpWidget(const SizedBox());
  });
}
