import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/games/core/tr_norm.dart';

void main() {
  group('trNorm — Türkçe-duyarsız arama', () {
    test('Türkçe I/İ kuralları', () {
      expect(trNorm('İlkay'), 'ilkay');
      expect(trNorm('IRFAN'), 'irfan');
      expect(trNorm('ılgaz'), 'ilgaz');
    });
    test('aksan temizliği', () {
      expect(trNorm('Gündoğan'), 'gundogan');
      expect(trNorm('Šeško'), 'sesko');
      expect(trNorm('Müller'), 'muller');
      expect(trNorm('Çalhanoğlu'), 'calhanoglu');
      expect(trNorm('İcardi'), 'icardi');
    });
    test('HTML norm() ile davranış eşitliği örnekleri', () {
      // oyunlardaki aramayla ayni sonucu vermeli
      expect(trNorm('MUSLERA'), 'muslera');
      expect(trNorm('güler'), 'guler');
    });
  });
}
