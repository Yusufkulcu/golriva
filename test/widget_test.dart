import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/genc_repository.dart';
import 'package:golriva/data/hedef_repository.dart';
import 'package:golriva/data/players_repository.dart';
import 'package:golriva/screens/lobby.dart';
import 'package:golriva/games/en_genc_kadro/screen.dart';
import 'package:golriva/games/en_kisa_kadro/screen.dart';
import 'package:golriva/games/hedefi_tuttur/screen.dart';

/// Widget duman testleri.
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

  Widget lobi() => MaterialApp(
      home: LobbyScreen(repo: repo, gencRepo: gencRepo, hedefRepo: hedefRepo));

  testWidgets('Lobi: marka + oyun kartlari cizilir', (tester) async {
    await tester.pumpWidget(lobi());
    expect(find.text('EN KISA KADRO'), findsOneWidget);
    expect(find.text('EN GENÇ KADRO'), findsOneWidget);
    expect(find.text('HEDEFİ TUTTUR'), findsOneWidget);
    expect(find.textContaining('yakında'), findsWidgets); // pasif oyunlar
  });

  Future<void> gecisTesti(WidgetTester tester, String kart, Type ekran) async {
    await tester.pumpWidget(lobi());
    await tester.tap(find.text(kart));
    await tester.pump(); // navigasyon
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ekran), findsOneWidget);
    // sayac timer'i calisiyor — testten temiz cikmak icin ekrani kapat
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('Lobiden EN KISA KADRO gecisi', (tester) async {
    await gecisTesti(tester, 'EN KISA KADRO', EnKisaKadroScreen);
  });

  testWidgets('Lobiden EN GENÇ KADRO gecisi', (tester) async {
    await gecisTesti(tester, 'EN GENÇ KADRO', EnGencKadroScreen);
  });

  testWidgets('Lobiden HEDEFİ TUTTUR gecisi', (tester) async {
    await gecisTesti(tester, 'HEDEFİ TUTTUR', HedefiTutturScreen);
  });

  testWidgets('HEDEFİ TUTTUR: kor mekanik — secimden sonra deger "?" kalir',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: HedefiTutturScreen(repo: hedefRepo)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), 'messi');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Lionel Messi').first);
    await tester.pump(const Duration(milliseconds: 100));
    // deger acilmadi: kadroda "?" var, gercek deger yok
    expect(find.text('?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
