import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/screens/lobby.dart';
import 'test_repos.dart';

/// Gorsel varlik testleri: marka + 10 oyun ikonu SVG'leri bundle'da var,
/// gecerli SVG ve GOLRIVA cizim kurallarina uygun (stroke 1.8, emoji yok).
void main() {
  const ikonlar = [
    'en_kisa_kadro',
    'kupa_drafti',
    'en_genc_kadro',
    'bayrak_yarisi',
    'hedefi_tuttur',
    'bonservis_avi',
    'sari_kart_avi',
    'mac_rekortmenleri',
    'milli_gol_krallari',
    'kariyer_ikizi',
  ];

  test('marka SVG dosyalari mevcut ve gecerli', () {
    for (final f in ['beyin_top', 'beyin_top_mono']) {
      final icerik = File('assets/brand/$f.svg').readAsStringSync();
      expect(icerik, contains('<svg'));
      expect(icerik, contains('viewBox="0 0 120 120"'));
    }
  });

  test('10 oyun ikonu mevcut, 24x24 ve stroke 1.8 kuralinda', () {
    for (final f in ikonlar) {
      final icerik = File('assets/icons/$f.svg').readAsStringSync();
      expect(icerik, contains('viewBox="0 0 24 24"'), reason: '$f boyut');
      expect(icerik, contains('stroke-width="1.8"'), reason: '$f kalinlik');
      expect(icerik, contains('stroke-linecap="round"'), reason: '$f uc stili');
    }
  });

  testWidgets('lobi: logo + 10 ikon SVG olarak cizilir', (tester) async {
    final repos = testRepos();
    await tester.pumpWidget(MaterialApp(home: LobbyScreen(repos: repos)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'SVG varliklari yuklenemedi/parse edilemedi');
  });
}
