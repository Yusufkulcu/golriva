import 'dart:math';
import '../../data/ikiz_repository.dart';
import '../core/tr_norm.dart';

/// KARIYER IKIZI motoru — kaynak_kod/kariyer_ikizi.html'in birebir cevirisi.
/// Rastgele REFERANS oyuncu secilir (taninir: ilk 600 icinde, 100+ lig maci,
/// sari kart verisi olan). Kariyeri acik gosterilir. 5 soru: her soruda bir
/// kategori hedefi ("ŞL GOLÜ → 140" gibi) — iki oyuncu SIRAYLA, kor sekilde
/// o hedefe EN YAKIN kariyerli baska futbolcuyu yazar. Yakin olan puani alir.
/// Referans ve daha once yazilanlar tekrar yazilamaz. Cok puan kazanir.
const ikizSoruSayisi = 5;
const ikizTurSaniye = 20;

class IkizSoru {
  final String ad; // "ŞL GOLÜ"
  final String hedefGosterim; // "140" ya da "05.02.1985"
  final num hedefSayi; // karsilastirma degeri (tarihte dobGun)
  final num? Function(IkizOyuncu) deger;
  final bool tarihMi;
  IkizSoru(this.ad, this.hedefGosterim, this.hedefSayi, this.deger,
      {this.tarihMi = false});
}

class IkizAday {
  final int idx;
  final String? neden; // null / "Referans" / "Alındı"
  IkizAday(this.idx, this.neden);
}

/// Tek sorunun acilis sonucu.
class IkizSonuc {
  final IkizSoru soru;
  final List<int> cevap; // -1 bos, -2 sure doldu, >=0 oyuncu idx
  final int? kazananS; // null = berabere/ikisi de bos
  IkizSonuc(this.soru, this.cevap, this.kazananS);
}

class KariyerIkiziEngine {
  final IkizRepository repo;
  final Random rng;

  late final int refIdx;
  late final int ligIdx;
  late final List<IkizSoru> sorular;
  int soru = 0;
  int faz = 0;
  final List<int> cevap = [-1, -1];
  final Set<int> alinan = {};
  final List<int> skor = [0, 0];
  final List<IkizSonuc> sonuclar = [];
  bool soruKapandi = false; // reveal gosteriliyor
  bool bitti = false;

  KariyerIkiziEngine(this.repo, {Random? rng, int? sabitRef})
      : rng = rng ?? Random() {
    final refler = <int>[];
    for (var i = 0; i < repo.oyuncular.length && i < 600; i++) {
      final o = repo.oyuncular[i];
      if (o.ligMac.reduce(max) >= 100 && o.sari >= 0) refler.add(i);
    }
    refIdx = sabitRef ?? refler[this.rng.nextInt(refler.length)];
    alinan.add(refIdx);
    final r = repo.oyuncular[refIdx];
    final maxMac = r.ligMac.reduce(max);
    ligIdx = r.ligMac.indexOf(maxMac);
    final hepsi = tumKategoriler();
    hepsi.shuffle(this.rng);
    sorular = hepsi.take(ikizSoruSayisi).toList();
  }

  IkizOyuncu get ref => repo.oyuncular[refIdx];

  List<IkizSoru> tumKategoriler() {
    final r = ref;
    final lig = repo.ligler[ligIdx].toUpperCase();
    return [
      IkizSoru('$lig MAÇI', '${r.ligMac[ligIdx]}', r.ligMac[ligIdx],
          (p) => p.ligMac[ligIdx]),
      IkizSoru('$lig GOLÜ', '${r.ligGol[ligIdx]}', r.ligGol[ligIdx],
          (p) => p.ligGol[ligIdx]),
      IkizSoru('ŞL GOLÜ', '${r.clGol}', r.clGol, (p) => p.clGol),
      IkizSoru('ŞL ASİSTİ', '${r.clAsist}', r.clAsist, (p) => p.clAsist),
      IkizSoru('SARI KART', '${r.sari}', r.sari,
          (p) => p.sari < 0 ? null : p.sari),
      IkizSoru('DOĞUM TARİHİ', r.dogumStr, r.dobGun, (p) => p.dobGun,
          tarihMi: true),
    ];
  }

  int starter(int q) => q % 2;
  int get simdiYazan => faz == 0 ? starter(soru) : 1 - starter(soru);
  IkizSoru get aktifSoru => sorular[soru];

  /// Min 3 harf; tum havuz; sebepli engeller (Referans/Alındı).
  List<IkizAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <IkizAday>[], iceren = <IkizAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      final neden =
          alinan.contains(i) ? (i == refIdx ? 'Referans' : 'Alındı') : null;
      ((pos == 0 || apos == 0) ? basla : iceren).add(IkizAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  bool sec(int idx) {
    if (bitti || soruKapandi) return false;
    if (alinan.contains(idx)) return false;
    alinan.add(idx);
    cevap[simdiYazan] = idx;
    _ilerle();
    return true;
  }

  void sureDoldu() {
    if (bitti || soruKapandi) return;
    cevap[simdiYazan] = -2;
    _ilerle();
  }

  void _ilerle() {
    if (faz == 0) {
      faz = 1;
    } else {
      _soruyuAc();
    }
  }

  void _soruyuAc() {
    final k = aktifSoru;
    num mesafe(int i) {
      if (i < 0) return 1e12;
      final v = k.deger(repo.oyuncular[i]);
      if (v == null) return 1e12;
      return (v - k.hedefSayi).abs();
    }

    final d0 = mesafe(cevap[0]), d1 = mesafe(cevap[1]);
    int? w;
    if (d0 < d1) {
      w = 0;
    } else if (d1 < d0) {
      w = 1;
    }
    if (w != null) skor[w]++;
    sonuclar.add(IkizSonuc(k, [...cevap], w));
    soruKapandi = true;
  }

  /// Cevap gosterimi ("—", "?", deger ya da tarih).
  String cevapGoster(IkizSoru k, int i) {
    if (i < 0) return '—';
    final v = k.deger(repo.oyuncular[i]);
    if (v == null) return '?';
    if (k.tarihMi) return repo.oyuncular[i].dogumStr;
    return '$v';
  }

  /// Sonraki soruya gec (UI reveal'den sonra cagirir).
  void sonrakiSoru() {
    if (!soruKapandi) return;
    soru++;
    if (soru >= ikizSoruSayisi) {
      bitti = true;
      return;
    }
    faz = 0;
    cevap[0] = -1;
    cevap[1] = -1;
    soruKapandi = false;
  }

  /// null = berabere, 0/1 = kazanan (cok puan)
  int? kazanan() {
    if (skor[0] == skor[1]) return null;
    return skor[0] > skor[1] ? 0 : 1;
  }
}
