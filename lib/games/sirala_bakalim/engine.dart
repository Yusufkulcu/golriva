import 'dart:math';
import '../../data/repos.dart';

/// SIRALA BAKALIM motoru (Faz 2.18 · v2 — kullanıcı kararı).
/// v2: İKİ OYUNCU DA AYNI TURLARI SIRALAR — farklı soru haksızlıktı.
/// Her turda bir METRİK ve 4 futbolcu gelir (değerler GİZLİ). İki taraf da
/// 4'ünü YÜKSEKTEN DÜŞÜĞE sıralar (çevrimiçi EŞ ZAMANLI; hot-seat'te
/// sırayla — önce O1, sonra O2, açılış ikisi de bitince). Her doğru konum
/// +1 (4'ü de doğruysa +1 bonus = 5). Tur, İKİ taraf da gönderince kapanır.
/// 4 tur; toplam puan kazanır.
/// Seed determinizmi: iki istemci aynı turları türetir.
const siralaTurSayisi = 4;
const siralaOyuncuSayisi = 4;
// Metriğin en iyi 100'ü (kullanıcı kararı: 250 fazla niş kaçıyordu,
// daha tanınmış/popüler isimler gelsin).
const siralaHavuzN = 100;
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

  /// [tur][taraf] → verilen dizi (null = henüz; boş liste = süre doldu).
  final List<List<List<int>?>> verilenler = [
    for (var i = 0; i < siralaTurSayisi; i++) [null, null]
  ];

  /// [tur][taraf] → puan (null = henüz gönderilmedi).
  final List<List<int?>> puanlar = [
    for (var i = 0; i < siralaTurSayisi; i++) [null, null]
  ];
  bool bitti = false;

  bool gonderdi(int s) => puanlar[tur][s] != null;

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

  /// [taraf]'ın bu tur sıralaması. Dönüş: alınan puan (geçersizde null).
  /// Tur, İKİ taraf da gönderince ilerler.
  int? sirala(int taraf, List<int> dizi) {
    if (bitti || gonderdi(taraf)) return null;
    if (dizi.length != siralaOyuncuSayisi) return null;
    if (dizi.toSet().length != siralaOyuncuSayisi) return null;
    if (dizi.any((i) => i < 0 || i >= siralaOyuncuSayisi)) return null;
    final dogru = aktifTur.dogruSira();
    var puan = 0;
    for (var i = 0; i < siralaOyuncuSayisi; i++) {
      if (dizi[i] == dogru[i]) puan++;
    }
    if (puan == siralaOyuncuSayisi) puan += siralaBonus; // kusursuz bonusu
    skor[taraf] += puan;
    puanlar[tur][taraf] = puan;
    verilenler[tur][taraf] = List.of(dizi);
    _kontrol();
    return puan;
  }

  /// [taraf]'ın süresi doldu: 0 puanla kapanır.
  void sureDoldu(int taraf) {
    if (bitti || gonderdi(taraf)) return;
    puanlar[tur][taraf] = 0;
    verilenler[tur][taraf] = const [];
    _kontrol();
  }

  void _kontrol() {
    if (puanlar[tur][0] == null || puanlar[tur][1] == null) return;
    if (tur + 1 >= siralaTurSayisi) {
      bitti = true;
    } else {
      tur++;
    }
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
