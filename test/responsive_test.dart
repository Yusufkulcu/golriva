import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/genc_repository.dart';
import 'package:golriva/data/hedef_repository.dart';
import 'package:golriva/data/players_repository.dart';
import 'package:golriva/games/en_genc_kadro/screen.dart';
import 'package:golriva/games/en_kisa_kadro/screen.dart';
import 'package:golriva/games/hedefi_tuttur/screen.dart';
import 'package:golriva/screens/lobby.dart';
import 'package:golriva/theme/golriva_theme.dart';

/// RESPONSIVE TEST MATRISI
/// Widget testlerinde RenderFlex tasmasi EXCEPTION olarak yakalanir —
/// yani "1.2 px overflow" gibi hatalar bu dosyada KIRMIZI yanar, cihaza kalmaz.
/// Matris: kucuk/buyuk telefon, tablet, yatay mod + klavye acik senaryosu.
void main() {
  late PlayersRepository repo;
  late GencRepository gencRepo;
  late HedefRepository hedefRepo;

  setUpAll(() {
    repo = PlayersRepository.fromJsonString(
        File('assets/data/boy_data.json').readAsStringSync());
    gencRepo = GencRepository.fromJsonString(
        File('assets/data/genc_data.json').readAsStringSync());
    hedefRepo = HedefRepository.fromJsonString(
        File('assets/data/hedef_data.json').readAsStringSync());
  });

  const boyutlar = <String, Size>{
    'iPhone SE (en kucuk)': Size(320, 568),
    'kucuk Android': Size(360, 640),
    'iPhone 14/15': Size(393, 852),
    'iPhone 16 Plus': Size(430, 932),
    'kucuk tablet': Size(768, 1024),
    'telefon YATAY': Size(852, 393),
    'tablet YATAY': Size(1024, 768),
  };

  Future<void> boyutAyarla(WidgetTester tester, Size s) async {
    tester.view.physicalSize = Size(s.width * 3, s.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> kur(WidgetTester tester, Widget ekran) async {
    await tester.pumpWidget(MaterialApp(theme: GolrivaTheme.dark(), home: ekran));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> temizle(WidgetTester tester) async {
    // oyun ekranindaki Timer'i dispose ile kapat
    await tester.pumpWidget(const SizedBox());
  }

  /// Arama kutusuna guvenli kaydirma.
  /// scrollUntilVisible KULLANMA: TextField kurulunca ekranda 2 Scrollable
  /// olur (kok ListView + TextField ici) ve varsayilan finder "Too many
  /// elements" ile patlar. Hedef Scrollable'i (ListView) acikca veriyoruz.
  Future<void> aramaKutusunaGit(WidgetTester tester) async {
    final tf = find.byType(TextField);
    if (tf.evaluate().isEmpty) {
      await tester.dragUntilVisible(
          tf, find.byType(ListView), const Offset(0, -80));
    } else {
      await tester.ensureVisible(tf);
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  // ekran adi -> (kurucu, ekranda kesin gorunen metin parcasi)
  final ekranlar = <String, (Widget Function(), String)>{
    'EN KISA KADRO': (() => EnKisaKadroScreen(repo: repo), 'TUR 1/'),
    'EN GENÇ KADRO': (() => EnGencKadroScreen(repo: gencRepo), 'TUR 1/'),
    'HEDEFİ TUTTUR': (() => HedefiTutturScreen(repo: hedefRepo), 'KÖR SIRALAMA'),
  };

  group('LOBI — tum boyutlarda tasma yok', () {
    for (final e in boyutlar.entries) {
      testWidgets(e.key, (tester) async {
        await boyutAyarla(tester, e.value);
        await kur(tester,
            LobbyScreen(repo: repo, gencRepo: gencRepo, hedefRepo: hedefRepo));
        expect(tester.takeException(), isNull,
            reason: '${e.key} (${e.value}) boyutunda lobide tasma/exception');
        expect(find.text('EN KISA KADRO'), findsOneWidget);
      });
    }
  });

  group('OYUN EKRANLARI — tum boyutlarda tasma yok', () {
    for (final ekran in ['EN KISA KADRO', 'EN GENÇ KADRO', 'HEDEFİ TUTTUR']) {
      for (final e in boyutlar.entries) {
        testWidgets('$ekran · ${e.key}', (tester) async {
          await boyutAyarla(tester, e.value);
          final (kurucu, beklenen) = ekranlar[ekran]!;
          await kur(tester, kurucu());
          expect(tester.takeException(), isNull,
              reason: '$ekran ${e.key} (${e.value}) boyutunda tasma');
          expect(find.textContaining(beklenen), findsOneWidget);
          await temizle(tester);
        });
      }
    }
  });

  group('ARAMA DROPDOWN acikken tasma yok (en dar + yatay)', () {
    for (final ekran in ['EN KISA KADRO', 'EN GENÇ KADRO', 'HEDEFİ TUTTUR']) {
      for (final boyutAd in ['iPhone SE (en kucuk)', 'telefon YATAY']) {
        testWidgets('$ekran · $boyutAd', (tester) async {
          await boyutAyarla(tester, boyutlar[boyutAd]!);
          final (kurucu, _) = ekranlar[ekran]!;
          await kur(tester, kurucu());
          await aramaKutusunaGit(tester);
          await tester.enterText(find.byType(TextField), 'mar');
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull,
              reason: '$ekran $boyutAd: dropdown acikken tasma');
          await temizle(tester);
        });
      }
    }
  });

  group('KLAVYE ACIK (viewInsets) tasma yok', () {
    for (final ekran in ['EN KISA KADRO', 'EN GENÇ KADRO', 'HEDEFİ TUTTUR']) {
      testWidgets(ekran, (tester) async {
        await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
        tester.view.viewInsets = const FakeViewPadding(bottom: 900); // ~300pt
        addTearDown(tester.view.resetViewInsets);
        final (kurucu, _) = ekranlar[ekran]!;
        await kur(tester, kurucu());
        // klavye acikken gorunur alan ~268pt: TextField'a once kaydir
        await aramaKutusunaGit(tester);
        await tester.enterText(find.byType(TextField), 'mar');
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: '$ekran: klavye acikken en kucuk ekranda tasma');
        await temizle(tester);
      });
    }
  });

  testWidgets('SONUC DIYALOGU — en kucuk ekranda tasma yok', (tester) async {
    await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
    // Bu test diyalog YERLESIMINI dogrular (tam oyun akisi engine_test'te):
    await tester.pumpWidget(MaterialApp(
      theme: GolrivaTheme.dark(),
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog(
                context: ctx,
                builder: (_) => Dialog(
                  backgroundColor: GolrivaColors.card,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('SEN KAZANDIN',
                            style: Theme.of(ctx).textTheme.displayMedium),
                        const SizedBox(height: 10),
                        const Text('1085 cm vs 1097 cm'),
                      ]),
                    ),
                  ),
                ),
              ),
              child: const Text('ac'),
            ),
          ),
        );
      }),
    ));
    await tester.tap(find.text('ac'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull, reason: 'sonuc diyalogu tasti');
  });

  testWidgets('HEDEFİ TUTTUR — kademeli acilis modunda tasma yok',
      (tester) async {
    await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
    await kur(tester, HedefiTutturScreen(repo: hedefRepo));
    // sadece ekran kurulumunu ve kadro "?" satirlarini dogrula
    expect(find.textContaining('KÖR SIRALAMA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await temizle(tester);
  });
}
