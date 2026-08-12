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
import 'package:golriva/screens/cuzdan_ekrani.dart';
import 'package:golriva/screens/kilavuz_ekrani.dart';
import 'package:golriva/screens/magaza_sekmesi.dart';
import 'package:golriva/screens/ligler_ekrani.dart';
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
    // DÜELLOLAR yok (profil altinda); MAĞAZA yeni sekme — 4 sekme
    expect(find.text('DÜELLOLAR'), findsNothing);
    for (final s in ['OYNA', 'SIRALAMA', 'MAĞAZA', 'PROFİL']) {
      expect(find.text(s), findsWidgets, reason: '$s sekmesi eksik');
    }
    // kart metinleri fiyat icerir: 'HIZLI DÜELLO · 100', 'BO3 SERİ · 250'
    expect(find.textContaining('HIZLI DÜELLO'), findsOneWidget);
    expect(find.text('MASALAR'), findsOneWidget);
    expect(find.textContaining('BO3 SERİ'), findsOneWidget);
    expect(find.text('ARKADAŞLA'), findsOneWidget);
    // tasarim kurali: ranked lobide oyun listesi OLMAZ (rulet secer)
    expect(find.text('EN KISA KADROYU KUR'), findsNothing);
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

  testWidgets('Arkadasla: RULET + 17 oyun karti cizilir', (tester) async {
    await tester.pumpWidget(arkadasla());
    // adlar arkadasla_ekrani._oyunlar() ile birebir ayni sirada
    for (final ad in [
      'RULET',
      'KUPA DRAFTI',
      'EN KISA KADROYU KUR',
      'EN GENÇ KADROYU KUR',
      'BAYRAK YARIŞI',
      'HEDEFİ TUTTUR',
      'BONSERVİS AVI',
      'SARI KART AVI',
      'MAÇ REKORTMENLERİ',
      'MİLLİ TAKIM GOL KRALLARI',
      'KARİYER İKİZİ',
      "BONSERVİS 21'İ",
      'VETO DRAFTI',
      'KİM BU?',
      'DAHA MI YÜKSEK?',
      'SIRALA BAKALIM',
      'ORTAK KULÜP AVI',
      'ŞL GECESİ',
    ]) {
      await kartaGit(tester, ad);
      expect(find.text(ad), findsOneWidget, reason: '$ad karti eksik');
    }
  });

  testWidgets('Arkadasla: davet kur + kodla katil butonlari var',
      (tester) async {
    await tester.pumpWidget(arkadasla());
    expect(find.text('DAVET KUR'), findsOneWidget);
    expect(find.text('KODLA KATIL'), findsOneWidget);
    expect(find.textContaining('Arkadaşlarım'), findsOneWidget);
  });

  testWidgets('Davet kur: oyun secimi + mod + olustur butonu', (tester) async {
    await tester
        .pumpWidget(MaterialApp(home: DavetKurEkrani(repos: repos)));
    expect(find.text('RULET'), findsOneWidget);
    // SERİ bolumu artik EN USTTE — asagi kaydirinca tembel ListView onu
    // bosaltir, o yuzden ONCE kontrol et
    expect(find.text('TEK MAÇ'), findsOneWidget);
    expect(find.text('3 MAÇLIK SERİ'), findsOneWidget);
    // sabit oyun secilebilir (ust bolge — once dokun, sonra kaydir)
    await tester.tap(find.text('KUPA DRAFTI'));
    await tester.pump();
    // buton 17 oyunluk listenin altinda — kaydirarak eris
    await tester.dragUntilVisible(find.text('DAVET KODU OLUŞTUR'),
        find.byType(ListView).first, const Offset(0, -100));
    expect(find.text('DAVET KODU OLUŞTUR'), findsOneWidget);
  });

  testWidgets('Ligler: 7 kademe cevrimdisi yedekle cizilir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LiglerEkrani()));
    await tester.pump(const Duration(milliseconds: 50));
    // ekran zirveden asagi listeler — test de ayni yonde kaydirir
    for (final ad in ['ŞAMPİYONLAR LİGİ', 'SÜPER LİG', 'AMATÖR KÜME']) {
      await tester.dragUntilVisible(
          find.text(ad), find.byType(ListView).first, const Offset(0, -120));
      expect(find.text(ad), findsOneWidget, reason: '$ad eksik');
    }
  });

  testWidgets('Arkadaslar: cevrimdisi kibarca aciklar', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ArkadaslarEkrani(repos: repos)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('çevrimiçi hesap gerekli'), findsOneWidget);
  });

  testWidgets('Auth: giris/kayit/misafir secenekleri cizilir', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AuthEkrani(repos: repos)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('GİRİŞ YAP'), findsWidgets); // baslik + buton
    expect(find.text('KAYIT OL'), findsOneWidget);
    expect(find.text('MİSAFİR OLARAK OYNA'), findsOneWidget);
    expect(find.text('Şifremi unuttum'), findsOneWidget);
    // kayit adimina gecis
    await tester.tap(find.text('KAYIT OL'));
    await tester.pump();
    expect(find.text('HESAP AÇ · +500 RIVA'), findsOneWidget);
  });

  testWidgets('Kilavuz: temel bolumler cizilir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KilavuzEkrani()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ELO NEDİR?'), findsOneWidget);
    expect(find.text('RIVA NEDİR?'), findsOneWidget);
    await tester.dragUntilVisible(find.text('ADALET & VERİ'),
        find.byType(ListView).first, const Offset(0, -150));
    expect(find.text('ADALET & VERİ'), findsOneWidget);
  });

  testWidgets('Magaza: reklam + fiyatli paketler; dokununca cokmez',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MagazaSekmesi())));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Reklam izle'), findsOneWidget);
    expect(find.text('RIVA PAKETLERİ'), findsOneWidget);
    expect(find.text('500'), findsOneWidget); // paket miktari
    expect(find.text('5.000'), findsOneWidget); // binlik ayirici
    // fiyat rozetleri: canli fiyat yoksa 'Mağazada' yazar (3 paket)
    expect(find.text('Mağazada'), findsNWidgets(3));
    // VM'de reklam desteklenmez → kibarca snackbar, cokme yok
    await tester.tap(find.text('Reklam izle'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('yalnız telefonda'), findsOneWidget);
  });

  testWidgets('Cuzdan: sade — gecmis var, magaza/reklam/duello karti YOK',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CuzdanEkrani()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('GEÇMİŞ'), findsOneWidget);
    // kullanici istegi: "Düello kazanarak" bilgilendirmesi kaldirildi
    expect(find.textContaining('Düello kazan'), findsNothing);
    expect(find.text('Reklam izle'), findsNothing); // magazaya tasindi
    expect(find.text('PAKETLER'), findsNothing);
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
    await gecisTesti(t, 'EN KISA KADROYU KUR', EnKisaKadroScreen);
  });
  testWidgets('Gecis: KUPA DRAFTI', (t) async {
    await gecisTesti(t, 'KUPA DRAFTI', KupaDraftiScreen);
  });
  testWidgets('Gecis: EN GENÇ KADRO', (t) async {
    await gecisTesti(t, 'EN GENÇ KADROYU KUR', EnGencKadroScreen);
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
