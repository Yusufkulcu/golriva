import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/online/uzak_ayar.dart';

/// FAZ 2.30 — uzak ayar: sürüm kıyası ve anahtar çözümü (ağsız).
void main() {
  group('UzakAyar.surumKiyasla', () {
    test('sayısal kıyas (sözlük değil): 1.0.10 > 1.0.9', () {
      expect(UzakAyar.surumKiyasla('1.0.10', '1.0.9'), greaterThan(0));
      expect(UzakAyar.surumKiyasla('1.0.9', '1.0.10'), lessThan(0));
    });
    test('eşitlik ve eksik parça (1.1 == 1.1.0)', () {
      expect(UzakAyar.surumKiyasla('1.1', '1.1.0'), 0);
      expect(UzakAyar.surumKiyasla('2.0.0', '1.9.9'), greaterThan(0));
    });
    test('+build eki yok sayılır', () {
      expect(UzakAyar.surumKiyasla('1.0.10+11', '1.0.10'), 0);
    });
  });

  group('UzakAyar.uygula', () {
    test('metin bayraklar ve sınırlar', () {
      UzakAyar.uygula({
        'bakim_modu': '1',
        'reklam_acik': '0',
        'gecis_reklam_yuzde': '150', // 0-100'e kırpılır
        'magaza_acik': 'true',
        'arkadas_ligi_acik': 'hayır',
        'min_surum_ios': '1.2.3',
      });
      expect(UzakAyar.bakimModu, isTrue);
      expect(UzakAyar.reklamAcik, isFalse);
      expect(UzakAyar.gecisReklamYuzde, 100);
      expect(UzakAyar.magazaAcik, isTrue);
      expect(UzakAyar.arkadasLigiAcik, isFalse);
      expect(UzakAyar.minSurumIos, '1.2.3');
      // geri al (diğer testler etkilenmesin)
      UzakAyar.uygula({
        'bakim_modu': '0',
        'reklam_acik': '1',
        'gecis_reklam_yuzde': '50',
        'arkadas_ligi_acik': '1',
      });
    });
    test('boş/bozuk değer varsayılanı bozmaz', () {
      UzakAyar.uygula({'gecis_reklam_yuzde': 'abc', 'reklam_acik': ''});
      expect(UzakAyar.gecisReklamYuzde, 50);
      expect(UzakAyar.reklamAcik, isTrue);
    });
    test('sürüm kapısı: mevcut < min → eski', () {
      UzakAyar.mevcutSurum = '1.0.9';
      UzakAyar.uygula({'min_surum_android': '1.0.10', 'min_surum_ios': '1.0.10'});
      expect(UzakAyar.surumEski, isTrue);
      UzakAyar.mevcutSurum = '1.0.10';
      expect(UzakAyar.surumEski, isFalse);
      UzakAyar.mevcutSurum = '0.0.0'; // bilinmiyorsa kapı kapanmaz
      expect(UzakAyar.surumEski, isFalse);
    });
  });
}
