import 'dart:math';
import '../../data/repos.dart';

/// SIRALA BAKALIM motoru (Faz 2.18 — yeni oyun).
/// Her turda bir METRİK ve 4 futbolcu gelir (değerler GİZLİ). Sıradaki
/// oyuncu 4'ünü YÜKSEKTEN DÜŞÜĞE sıralar. Her doğru konum +1 puan
/// (4'ü de doğruysa +1 bonus = 5). 4 tur, 2'şer sıralama; toplam kazanır.
/// Seed determinizmi: iki istemci aynı turları türetir.
const siralaTurSayisi = 4;
const siralaOyuncuSayisi = 4;
const siralaHavuzN = 250; // metriğin en iyi 250'si (tanınırlık)
const siralaBonus = 1; // kusursuz sıralama bonusu

class SiralaTur {
  final String metrikAd;
  final String birim;
  final List<String> oyuncuAdlari; // gösterim sırası (karışık)
  final List<double> degerler; // oyuncuAdlari ile hizalı — GİZLİ
  SiralaTur(this.metrikAd, this.birim, this.oyuncuAdlari, this.degerler);

  /// Doğru sıralama: gösterim indekslerinin YÜKSEKTEN DÜŞÜĞE dizilişi.
  List<int> dogruSira() {
    final idx = List<int>.generate(oyuncuAdlari.length, (i) => i)
      ..sort((a, b) => degerler[b].compareTo(degerler[a]));
    return idx;
  }
}

class SiralaBakalimEngine {
  final Random rng;

  late final List<SiralaTur> turlar;
  int tur = 0;
  final List<int> skor = [0, 0];
  final List<int?> turPuanlari = []; // null = süre doldu (0 sayılır)
  final List<List<int>> verilenSiralar = []; // gösterim için
  bool bitti = false;

  int get aktor => tur % 2;
  SiralaTur get aktifTur => turlar[tur];

  SiralaBakalimEngine(GolrivaRepos repos, {Random? rng})
      : rng = rng ?? Random() {
    List<(String, double)> top(Iterable<(String, double)> ham) =>
        (ham.toList()..sort((a, b) => b.$2.compareTo(a.$2)))
            .take(siralaHavuzN)
            .toList();
    final metrikler = <(String, String, List<(String, double)>)>[
      ('BONSERVİS', 'M€', top(repos.fee.oyuncular.map((o) => (o.ad, o.deger)))),
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
    // 5 metrikten rastgele 4'ü, tekrarsız.
    final secim = List<int>.generate(5, (i) => i)..shuffle(this.rng);
    turlar = [
      for (final m in secim.take(siralaTurSayisi)) _turUret(metrikler[m]),
    ];
  }

  SiralaTur _turUret((String, String, List<(String, double)>) metrik) {
    final liste = metrik.$3;
    // Değerleri BİRBİRİNDEN FARKLI 4 oyuncu çek (deterministik).
    final adlar = <String>[], degerler = <double>[];
    for (var deneme = 0;
        deneme < 200 && adlar.length < siralaOyuncuSayisi;
        deneme++) {
      final a = liste[rng.nextInt(liste.length)];
      if (adlar.contains(a.$1) || degerler.contains(a.$2)) continue;
      adlar.add(a.$1);
      degerler.add(a.$2);
    }
    // teorik emniyet: eksik kalırsa liste başından benzersizlerle doldur
    for (var i = 0; adlar.length < siralaOyuncuSayisi && i < liste.length; i++) {
      final a = liste[i];
      if (adlar.contains(a.$1) || degerler.contains(a.$2)) continue;
      adlar.add(a.$1);
      degerler.add(a.$2);
    }
    return SiralaTur(metrik.$1, metrik.$2, adlar, degerler);
  }

  /// Aktörün sıralaması: gösterim indekslerinin dizilişi (yüksekten düşüğe).
  /// Dönüş: alınan puan (geçersiz girişte null).
  int? sirala(List<int> dizi) {
    if (bitti) return null;
    if (dizi.length != siralaOyuncuSayisi) return null;
    if (dizi.toSet().length != siralaOyuncuSayisi) return null;
    if (dizi.any((i) => i < 0 || i >= siralaOyuncuSayisi)) return null;
    final dogru = aktifTur.dogruSira();
    var puan = 0;
    for (var i = 0; i < siralaOyuncuSayisi; i++) {
      if (dizi[i] == dogru[i]) puan++;
    }
    if (puan == siralaOyuncuSayisi) puan += siralaBonus; // kusursuz bonusu
    skor[aktor] += puan;
    turPuanlari.add(puan);
    verilenSiralar.add(List.of(dizi));
    _ilerle();
    return puan;
  }

  /// Süre dolumu: sıralama yok, 0 puan.
  void sureDoldu() {
    if (bitti) return;
    turPuanlari.add(null);
    verilenSiralar.add(const []);
    _ilerle();
  }

  void _ilerle() {
    if (tur + 1 >= siralaTurSayisi) {
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
String siralaFmt(double v) => v % 1 == 0
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');
