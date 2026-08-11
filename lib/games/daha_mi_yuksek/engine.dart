import 'dart:math';
import '../../data/repos.dart';

/// DAHA MI YÜKSEK? motoru (Faz 2.18 — yeni oyun).
/// Her turda bir METRİK (bonservis / sarı kart / kupa / maç / milli gol)
/// ve iki futbolcu gelir: SOLDAKİNİN değeri AÇIK, sağdakininki GİZLİ.
/// Sıradaki oyuncu karar verir: sağdaki DAHA MI YÜKSEK, DAHA MI DÜŞÜK?
/// Doğru = +1. 10 tur (5'er karar), toplam yüksek kazanır.
/// Seed determinizmi: iki istemci aynı soruları türetir.
const dahaTurSayisi = 10;
const dahaHavuzN = 250; // sorular metriğin en iyi 250'sinden (tanınırlık)

class DahaSoru {
  final String metrikAd; // 'BONSERVİS' gibi
  final String birim; // 'M€' gibi
  final String solAd;
  final double solDeger;
  final String sagAd;
  final double sagDeger; // GİZLİ — cevaptan sonra açılır
  DahaSoru(this.metrikAd, this.birim, this.solAd, this.solDeger, this.sagAd,
      this.sagDeger);

  bool get sagYuksek => sagDeger > solDeger;
}

class DahaMiYuksekEngine {
  final Random rng;

  late final List<DahaSoru> sorular;
  int tur = 0;
  final List<int> skor = [0, 0];
  final List<bool?> dogruMu = []; // tur başına sonuç (null = süre doldu)
  bool bitti = false;

  /// Karar sırası: turlar dönüşümlü (0,1,0,1...) — 5'er karar.
  int get aktor => tur % 2;

  DahaSoru get soru => sorular[tur];

  DahaMiYuksekEngine(GolrivaRepos repos, {Random? rng})
      : rng = rng ?? Random() {
    // Metrik listeleri: (ad, birim, [(oyuncuAd, deger)...] en iyi N).
    List<(String, double)> top(
            Iterable<(String, double)> ham) =>
        (ham.toList()..sort((a, b) => b.$2.compareTo(a.$2)))
            .take(dahaHavuzN)
            .toList();
    final metrikler = <(String, String, List<(String, double)>)>[
      (
        'BONSERVİS',
        'M€',
        top(repos.fee.oyuncular.map((o) => (o.ad, o.deger)))
      ),
      (
        'SARI KART',
        'sarı kart',
        top(repos.card.oyuncular.map((o) => (o.ad, o.deger)))
      ),
      (
        'KUPA SAYISI',
        'kupa',
        top(repos.kupa.oyuncular.map((o) => (o.ad, o.kupa.toDouble())))
      ),
      (
        'MAÇ SAYISI',
        'maç',
        top(repos.mac.oyuncular.map((o) => (o.ad, o.deger.toDouble())))
      ),
      (
        'MİLLİ GOL',
        'milli gol',
        top(repos.milligol.oyuncular.map((o) => (o.ad, o.deger.toDouble())))
      ),
    ];
    // Tur metrikleri: 5'li desteyi iki kez karıştırıp sırala —
    // her metrik tam 2 kez gelir, sıra tahmin edilemez.
    final sira = <int>[
      ...List.generate(5, (i) => i)..shuffle(this.rng),
      ...List.generate(5, (i) => i)..shuffle(this.rng),
    ];
    sorular = [
      for (final m in sira) _soruUret(metrikler[m]),
    ];
  }

  DahaSoru _soruUret((String, String, List<(String, double)>) metrik) {
    final liste = metrik.$3;
    // Farklı değerli iki oyuncu çek (deterministik yeniden deneme).
    for (var deneme = 0; deneme < 50; deneme++) {
      final a = liste[rng.nextInt(liste.length)];
      final b = liste[rng.nextInt(liste.length)];
      if (a.$1 == b.$1 || a.$2 == b.$2) continue;
      return DahaSoru(metrik.$1, metrik.$2, a.$1, a.$2, b.$1, b.$2);
    }
    // teorik emniyet: liste başı ve sonu kesin farklıdır
    final a = liste.first, b = liste.last;
    return DahaSoru(metrik.$1, metrik.$2, a.$1, a.$2, b.$1, b.$2);
  }

  /// Aktörün kararı. Doğruysa +1. Dönüş: doğru muydu.
  bool cevap({required bool yuksek}) {
    if (bitti) return false;
    final dogru = yuksek == soru.sagYuksek;
    if (dogru) skor[aktor]++;
    dogruMu.add(dogru);
    _ilerle();
    return dogru;
  }

  /// Süre dolumu: karar verilmedi, puan yok.
  void sureDoldu() {
    if (bitti) return;
    dogruMu.add(null);
    _ilerle();
  }

  void _ilerle() {
    if (tur + 1 >= dahaTurSayisi) {
      bitti = true;
      return;
    }
    tur++;
  }

  /// null = berabere · 0/1 = kazanan.
  int? kazanan() {
    if (skor[0] == skor[1]) return null;
    return skor[0] > skor[1] ? 0 : 1;
  }
}

/// Değer gösterimi: tam sayıysa "120", değilse "117,5" (TR virgül).
String dahaFmt(double v) => v % 1 == 0
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');
