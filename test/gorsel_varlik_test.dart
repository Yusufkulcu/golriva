import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/screens/ana_iskelet.dart';
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

  // golriva_ekranlar_v1.html tasarim setinin arayuz ikonlari
  const arayuzIkonlari = [
    'nav_oyna',
    'nav_siralama',
    'nav_duellolar',
    'nav_profil',
    'simsek',
    'riva',
    'oynat',
    'kupa_kucuk',
    'alev',
    'tac',
    'rulet',
    'kilit',
    'onay',
    'carpi',
  ];

  test('10 oyun ikonu mevcut, 24x24 ve stroke 1.8 kuralinda', () {
    for (final f in ikonlar) {
      final icerik = File('assets/icons/$f.svg').readAsStringSync();
      expect(icerik, contains('viewBox="0 0 24 24"'), reason: '$f boyut');
      expect(icerik, contains('stroke-width="1.8"'), reason: '$f kalinlik');
      expect(icerik, contains('stroke-linecap="round"'), reason: '$f uc stili');
    }
  });

  test('14 arayuz ikonu (tasarim seti) mevcut ve 24x24 kuralinda', () {
    for (final f in arayuzIkonlari) {
      final icerik = File('assets/icons/$f.svg').readAsStringSync();
      expect(icerik, contains('<svg'), reason: '$f gecersiz');
      expect(icerik, contains('viewBox="0 0 24 24"'), reason: '$f boyut');
    }
  });

  test('iOS uygulama ikonlari mevcut, dogru boyutta', () {
    const kontrol = {
      'Icon-App-1024x1024@1x.png': 1024,
      'Icon-App-60x60@3x.png': 180,
      'Icon-App-83.5x83.5@2x.png': 167,
      'Icon-App-20x20@1x.png': 20,
    };
    for (final e in kontrol.entries) {
      final b = File(
              'ios/Runner/Assets.xcassets/AppIcon.appiconset/${e.key}')
          .readAsBytesSync();
      int okuInt(int o) =>
          (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
      // PNG IHDR: genislik 16. bayttan, yukseklik 20. bayttan
      expect(okuInt(16), e.value, reason: '${e.key} genislik');
      expect(okuInt(20), e.value, reason: '${e.key} yukseklik');
    }
  });

  testWidgets('iskelet: logo + arayuz SVG ikonlari cizilir', (tester) async {
    final repos = testRepos();
    await tester.pumpWidget(MaterialApp(home: AnaIskelet(repos: repos)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'SVG varliklari yuklenemedi/parse edilemedi');
  });
}
