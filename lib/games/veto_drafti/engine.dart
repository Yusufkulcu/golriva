import 'dart:math';
import '../../data/kupa_repository.dart';
import '../core/tr_norm.dart';

/// VETO DRAFTI motoru (Faz 2.17 — yeni oyun).
/// Kupa Draftı kuralları (6 tur, rastgele kulüp, 1K-2D-2O-1F, kupa toplamı
/// YÜKSEK kazanır) + TAKTİK KATMAN: her oyuncunun maç başına 1 VETO hakkı
/// vardır. Rakip bir futbolcu seçtiğinde kısa bir veto penceresi açılır —
/// VETO dersen o futbolcu YAKILIR (kimse alamaz, kadroya girmez) ve rakip
/// aynı etap için YENİDEN seçer; GEÇ dersen seçim kesinleşir.
/// Veto hakkı kalmayan rakibin seçimleri pencereye uğramadan kesinleşir.
const vetoFormation = {'K': 1, 'D': 2, 'O': 2, 'F': 1};
const vetoSlotAd = {'K': 'Kaleci', 'D': 'Defans', 'O': 'Orta', 'F': 'Forvet'};
const vetoTurSayisi = 6;
const vetoHakSayisi = 1; // kullanici karari: mac basina TEK veto

enum VetoAsama { secim, veto }

class VetoAday {
  final int idx;
  final String? neden;
  VetoAday(this.idx, this.neden);
}

class VetoSecim {
  final String poz;
  final int idx;
  VetoSecim(this.poz, this.idx);
}

class VetoDraftEngine {
  final KupaRepository repo;
  final Random rng;

  late final List<int> kulupSirasi;
  int tur = 0;
  int faz = 0; // snake: 0 = öncelikli seçen, 1 = diğeri
  VetoAsama asama = VetoAsama.secim;
  int? adayIdx; // veto penceresinde bekleyen seçim
  final List<int> vetoHak = [vetoHakSayisi, vetoHakSayisi];
  final Set<int> alinan = {}; // kadroya giren + veto ile yakılanlar
  final List<List<VetoSecim>> kadrolar = [[], []];
  final List<int> bosEtap = [0, 0];
  bool bitti = false;

  VetoDraftEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    final idx = List<int>.generate(repo.kulupler.length, (i) => i)
      ..shuffle(this.rng);
    kulupSirasi = idx.take(vetoTurSayisi).toList();
  }

  int firstPicker(int t) => t % 2;
  int get simdiSecen => faz == 0 ? firstPicker(tur) : 1 - firstPicker(tur);

  /// Veto penceresinde karar RAKİBİNDİR.
  int get vetocu => 1 - simdiSecen;

  /// O anki "aktör": seçim aşamasında seçen, veto aşamasında vetocu.
  int get aktor => asama == VetoAsama.secim ? simdiSecen : vetocu;

  KupaKulup get kulup => repo.kulupler[kulupSirasi[tur]];

  List<String> acikMevkiler(int s) {
    final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
    for (final p in kadrolar[s]) {
      sayim[p.poz] = sayim[p.poz]! + 1;
    }
    return vetoFormation.keys
        .where((z) => sayim[z]! < vetoFormation[z]!)
        .toList();
  }

  /// Bu kulüp + açık mevki; min 3 harf; sebepli engeller.
  /// Kupa sayısı META'DA GÖSTERİLMEZ (seçince açılır) — veto kararı da
  /// rakibin bilgisine dayanır.
  /// v4.1: alias da aranır ("CR7" gibi takma adlar draft'ta çalışır).
  List<VetoAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final acik = acikMevkiler(simdiSecen);
    final basla = <VetoAday>[], iceren = <VetoAday>[];
    for (final i in kulup.havuz) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      String? neden;
      if (alinan.contains(i)) {
        neden = 'Alındı';
      } else if (!acik.contains(o.poz)) {
        neden = '${vetoSlotAd[o.poz]} dolu';
      }
      ((pos == 0 || apos == 0) ? basla : iceren).add(VetoAday(i, neden));
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Seçim: geçerliyse ya veto penceresine düşer (rakipte hak varsa)
  /// ya da anında kesinleşir.
  bool sec(int idx) {
    if (bitti || asama != VetoAsama.secim) return false;
    final o = repo.oyuncular[idx];
    if (!kulup.havuz.contains(idx)) return false;
    if (alinan.contains(idx)) return false;
    if (!acikMevkiler(simdiSecen).contains(o.poz)) return false;
    if (vetoHak[vetocu] > 0) {
      adayIdx = idx;
      asama = VetoAsama.veto;
    } else {
      _kesinlestir(idx);
    }
    return true;
  }

  /// Veto: bekleyen seçim YAKILIR (kimse alamaz), hak düşer,
  /// aynı seçen aynı etap için yeniden seçer.
  bool vetoYap() {
    if (bitti || asama != VetoAsama.veto || adayIdx == null) return false;
    if (vetoHak[vetocu] <= 0) return false;
    vetoHak[vetocu]--;
    alinan.add(adayIdx!); // yakıldı — havuzdan düştü
    adayIdx = null;
    asama = VetoAsama.secim;
    return true;
  }

  /// Geç: bekleyen seçim kesinleşir (veto penceresi süresi dolunca da).
  bool gec() {
    if (bitti || asama != VetoAsama.veto || adayIdx == null) return false;
    final idx = adayIdx!;
    adayIdx = null;
    asama = VetoAsama.secim;
    _kesinlestir(idx);
    return true;
  }

  void _kesinlestir(int idx) {
    alinan.add(idx);
    kadrolar[simdiSecen].add(VetoSecim(repo.oyuncular[idx].poz, idx));
    _ilerle();
  }

  /// Seçim süresi doldu: etap boş geçer. (Veto süresi dolumu için gec().)
  void sureDoldu() {
    if (bitti || asama != VetoAsama.secim) return;
    bosEtap[simdiSecen]++;
    _ilerle();
  }

  void _ilerle() {
    if (faz == 0) {
      faz = 1;
    } else {
      faz = 0;
      tur++;
    }
    if (tur >= vetoTurSayisi) bitti = true;
  }

  int toplam(int s) =>
      kadrolar[s].fold(0, (a, p) => a + repo.oyuncular[p.idx].kupa);

  /// null = berabere, 0/1 = kazanan (YÜKSEK kupa toplamı)
  int? kazanan() {
    final t0 = toplam(0), t1 = toplam(1);
    if (t0 == t1) return null;
    return t0 > t1 ? 0 : 1;
  }
}
