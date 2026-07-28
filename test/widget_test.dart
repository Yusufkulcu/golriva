import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/data/players_repository.dart';
import 'package:golriva/screens/lobby.dart';
import 'package:golriva/games/en_kisa_kadro/screen.dart';

/// Widget duman testleri — flutter create'in urettigi MyApp sablonunun yerine.
void main() {
  late PlayersRepository repo;

  setUpAll(() {
    final raw = File('assets/data/boy_data.json').readAsStringSync();
    repo = PlayersRepository.fromJsonString(raw);
  });

  testWidgets('Lobi: marka + oyun kartlari cizilir', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LobbyScreen(repo: repo)));
    expect(find.text('EN KISA KADRO'), findsOneWidget);
    expect(find.textContaining('yakında'), findsWidgets); // pasif oyunlar
  });

  testWidgets('Lobiden oyuna gecis + oyun ekrani kurulur', (tester) async {
    await tester.pumpWidget(MaterialApp(home: LobbyScreen(repo: repo)));
    await tester.tap(find.text('EN KISA KADRO'));
    await tester.pump(); // navigasyon
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EnKisaKadroScreen), findsOneWidget);
    expect(find.textContaining('TUR 1/'), findsOneWidget);
    // sayac timer'i calisiyor — testten temiz cikmak icin ekrani kapat
    await tester.pumpWidget(const SizedBox());
  });
}
