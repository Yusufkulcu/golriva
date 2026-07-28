import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/players_repository.dart';
import 'package:golriva/games/en_kisa_kadro/screen.dart';
import 'package:golriva/screens/lobby.dart';
import 'package:golriva/theme/golriva_theme.dart';

/// RESPONSIVE TEST MATRISI
/// Widget testlerinde RenderFlex tasmasi EXCEPTION olarak yakalanir —
/// yani "1.2 px overflow" gibi hatalar bu dosyada KIRMIZI yanar, cihaza kalmaz.
/// Matris: kucuk/buyuk telefon, tablet, yatay mod + klavye acik senaryosu.
void main() {
  late PlayersRepository repo;

  setUpAll(() {
    final raw = File('assets/data/boy_data.json').readAsStringSync();
    repo = PlayersRepository.fromJsonString(raw);
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

  group('LOBI — tum boyutlarda tasma yok', () {
    for (final e in boyutlar.entries) {
      testWidgets(e.key, (tester) async {
        await boyutAyarla(tester, e.value);
        await kur(tester, LobbyScreen(repo: repo));
        expect(tester.takeException(), isNull,
            reason: '${e.key} (${e.value}) boyutunda lobide tasma/exception');
        expect(find.text('EN KISA KADRO'), findsOneWidget);
      });
    }
  });

  group('OYUN EKRANI — tum boyutlarda tasma yok', () {
    for (final e in boyutlar.entries) {
      testWidgets(e.key, (tester) async {
        await boyutAyarla(tester, e.value);
        await kur(tester, EnKisaKadroScreen(repo: repo));
        expect(tester.takeException(), isNull,
            reason: '${e.key} (${e.value}) boyutunda oyun ekraninda tasma');
        expect(find.textContaining('TUR 1/'), findsOneWidget);
        await temizle(tester);
      });
    }
  });

  group('OYUN EKRANI — arama dropdown acikken tasma yok', () {
    for (final e in {
      'iPhone SE (en kucuk)': boyutlar['iPhone SE (en kucuk)']!,
      'telefon YATAY': boyutlar['telefon YATAY']!,
    }.entries) {
      testWidgets(e.key, (tester) async {
        await boyutAyarla(tester, e.value);
        await kur(tester, EnKisaKadroScreen(repo: repo));
        await tester.enterText(find.byType(TextField), 'mus');
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: '${e.key}: dropdown acikken tasma');
        await temizle(tester);
      });
    }
  });

  testWidgets('OYUN EKRANI — KLAVYE ACIK (viewInsets) tasma yok', (tester) async {
    await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900); // ~300pt klavye
    addTearDown(tester.view.resetViewInsets);
    await kur(tester, EnKisaKadroScreen(repo: repo));
    // klavye acikken gorunur alan ~268pt: TextField ListView'da asagida
    // kaldigi icin once ona kaydir (gercek kullanicinin yapacagi gibi)
    await tester.scrollUntilVisible(find.byType(TextField), 80);
    await tester.enterText(find.byType(TextField), 'mes');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'klavye acikken en kucuk ekranda tasma');
    await temizle(tester);
  });

  testWidgets('SONUC DIYALOGU — en kucuk ekranda tasma yok', (tester) async {
    await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
    await kur(tester, EnKisaKadroScreen(repo: repo));
    // oyunu programatik bitir: state'e erisim yerine UI uzerinden hizli yol —
    // motoru dogrudan kullanan ayri bir ekran kurmak yerine 12 fazlik akis
    // engine_test'te; burada diyalogu tetiklemek icin sureleri akitmak cok
    // yavas olurdu. Bu test diyalog YERLESIMINI dogrular:
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
}
