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
import 'package:golriva/online/auth_ekrani.dart';
import 'package:golriva/online/davet_ekrani.dart';
import 'package:golriva/screens/ana_iskelet.dart';
import 'package:golriva/screens/arkadasla_ekrani.dart';
import 'package:golriva/screens/arkadaslar_ekrani.dart';
import 'package:golriva/screens/kilavuz_ekrani.dart';
import 'package:golriva/screens/ligler_ekrani.dart';
import 'package:golriva/screens/magaza_sekmesi.dart';
import 'package:golriva/theme/golriva_theme.dart';
import 'test_repos.dart';

/// RESPONSIVE TEST MATRISI — 10 oyun x 7 ekran boyutu.
/// Widget testlerinde RenderFlex tasmasi EXCEPTION olarak yakalanir —
/// "1.2 px overflow" gibi hatalar burada KIRMIZI yanar, cihaza kalmaz.
void main() {
  late GolrivaRepos repos;

  setUpAll(() {
    repos = testRepos();
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
    // oyun ekranindaki Timer'lari dispose ile kapat
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
    'EN KISA KADRO': (() => EnKisaKadroScreen(repo: repos.boy), 'TUR 1/'),
    'KUPA DRAFTI': (() => KupaDraftiScreen(repo: repos.kupa), 'TUR 1/'),
    'EN GENÇ KADRO': (() => EnGencKadroScreen(repo: repos.genc), 'TUR 1/'),
    'BAYRAK YARIŞI': (
      () => BayrakYarisiScreen(repo: repos.boy),
      'İLK KAPAN'
    ),
    'HEDEFİ TUTTUR': (
      () => HedefiTutturScreen(repo: repos.hedef),
      'KÖR SIRALAMA'
    ),
    'BONSERVİS AVI': (
      () => KorAvScreen(repo: repos.fee, config: bonservisConfig),
      'KÖR SIRALAMA'
    ),
    'SARI KART AVI': (
      () => KorAvScreen(repo: repos.card, config: sariKartConfig),
      'KÖR SIRALAMA'
    ),
    'MAÇ REKORTMENLERİ': (
      () => SerbestKadroScreen(repo: repos.mac, config: macConfig),
      'TUR 1/'
    ),
    'MİLLİ GOL KRALLARI': (
      () => SerbestKadroScreen(repo: repos.milligol, config: milligolConfig),
      'TUR 1/'
    ),
    'KARİYER İKİZİ': (
      () => KariyerIkiziScreen(repo: repos.ikiz),
      'SORU 1/'
    ),
  };

  // aramasi acik baslayan ekranlar (bayrak haric: TextField KAP sonrasi acilir)
  const aramaliEkranlar = [
    'EN KISA KADRO',
    'KUPA DRAFTI',
    'EN GENÇ KADRO',
    'HEDEFİ TUTTUR',
    'BONSERVİS AVI',
    'SARI KART AVI',
    'MAÇ REKORTMENLERİ',
    'MİLLİ GOL KRALLARI',
    'KARİYER İKİZİ',
  ];

  group('ISKELET (lobi + 4 sekme) — tum boyutlarda tasma yok', () {
    for (final e in boyutlar.entries) {
      testWidgets(e.key, (tester) async {
        await boyutAyarla(tester, e.value);
        await kur(tester, AnaIskelet(repos: repos));
        expect(tester.takeException(), isNull,
            reason: '${e.key} (${e.value}) boyutunda lobide tasma/exception');
        expect(find.text('HIZLI DÜELLO'), findsOneWidget);
      });
    }
  });

  group('ARKADAŞLA OYNA — tum boyutlarda tasma yok', () {
    for (final e in boyutlar.entries) {
      testWidgets(e.key, (tester) async {
        await boyutAyarla(tester, e.value);
        await kur(tester, ArkadaslaEkrani(repos: repos));
        expect(tester.takeException(), isNull,
            reason:
                '${e.key} (${e.value}) boyutunda oyun secim ekraninda tasma');
        expect(find.text('RULET'), findsOneWidget);
      });
    }
  });

  group('YENI SAYFALAR — tum boyutlarda tasma yok', () {
    final sayfalar = <String, Widget Function()>{
      'LİGLER': () => const LiglerEkrani(),
      'ARKADAŞLAR': () => ArkadaslarEkrani(repos: repos),
      'DAVET KUR': () => DavetKurEkrani(repos: repos),
      'KILAVUZ': () => const KilavuzEkrani(),
      'AUTH': () => AuthEkrani(repos: repos),
      'MAĞAZA': () => const Scaffold(body: MagazaSekmesi()),
    };
    for (final s in sayfalar.keys) {
      for (final e in boyutlar.entries) {
        testWidgets('$s · ${e.key}', (tester) async {
          await boyutAyarla(tester, e.value);
          await kur(tester, sayfalar[s]!());
          expect(tester.takeException(), isNull,
              reason: '$s ${e.key} (${e.value}) boyutunda tasma');
          await temizle(tester);
        });
      }
    }
  });

  group('OYUN EKRANLARI — tum boyutlarda tasma yok', () {
    for (final ekran in ekranlar.keys) {
      for (final e in boyutlar.entries) {
        testWidgets('$ekran · ${e.key}', (tester) async {
          await boyutAyarla(tester, e.value);
          final (kurucu, beklenen) = ekranlar[ekran]!;
          await kur(tester, kurucu());
          expect(tester.takeException(), isNull,
              reason: '$ekran ${e.key} (${e.value}) boyutunda tasma');
          expect(find.textContaining(beklenen), findsWidgets);
          await temizle(tester);
        });
      }
    }
  });

  group('ARAMA DROPDOWN acikken tasma yok (en dar + yatay)', () {
    for (final ekran in aramaliEkranlar) {
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
    for (final ekran in aramaliEkranlar) {
      testWidgets(ekran, (tester) async {
        await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
        tester.view.viewInsets = const FakeViewPadding(bottom: 900); // ~300pt
        addTearDown(tester.view.resetViewInsets);
        final (kurucu, _) = ekranlar[ekran]!;
        await kur(tester, kurucu());
        await aramaKutusunaGit(tester);
        await tester.enterText(find.byType(TextField), 'mar');
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: '$ekran: klavye acikken en kucuk ekranda tasma');
        await temizle(tester);
      });
    }
  });

  testWidgets('BAYRAK YARIŞI — KAP sonrasi cevap kutusu en dar ekranda',
      (tester) async {
    await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
    await kur(tester, BayrakYarisiScreen(repo: repos.boy));
    await tester.ensureVisible(find.textContaining('KAP!').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.textContaining('KAP!').first);
    await tester.pump(const Duration(milliseconds: 50));
    await aramaKutusunaGit(tester);
    await tester.enterText(find.byType(TextField), 'mar');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'bayrak: cevap kutusu acikken tasma');
    await temizle(tester);
  });

  testWidgets('SONUC DIYALOGU — en kucuk ekranda tasma yok', (tester) async {
    await boyutAyarla(tester, boyutlar['iPhone SE (en kucuk)']!);
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
