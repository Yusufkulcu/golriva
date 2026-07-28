import 'dart:math';
import '../../data/genc_repository.dart';
import '../core/tr_norm.dart';

/// EN GENC KADRO motoru — kaynak_kod/en_genc_kadro.html'in birebir Dart cevirisi.
/// Kurallar: 6 tur, her tur rastgele KULUP (29 elit kulup); 1K-2D-2O-1F;
/// sadece AKTIF ve dogum tarihli oyuncular; yas OYNANIS ANINDA hesaplanir;
/// yaslar her secimden sonra ANINDA aciklanir ve ustte TOPLANARAK gider;
/// bos slot +60 yas ceza; oncelik her turda el degistirir; DUSUK toplam kazanir.
const gencFormation = {'K': 1, 'D': 2, 'O': 2, 'F': 1};
const gencSlotOrder = ['K', 'D', 'D', 'O', 'O', 'F'];
const gencSlotAd = {'K': 'Kaleci', 'D': 'Defans', 'O': 'Orta', 'F': 'Forvet'};
const gencBosCeza = 60.0; // yas — veri setindeki en yasli aktiften yuksek
const gencTurSayisi = 6;

class GencAday {
  final int idx;
  final String? neden; // null = secilebilir
  GencAday(this.idx, this.neden);
}

class GencSecim {
  final String poz;
  final int idx;
  GencSecim(this.poz, this.idx);
}

class GencKadroEngine {
  final GencRepository repo;
  final Random rng;

  /// Yas hesabi bu "an"a gore — testte sabitlenebilir, uygulamada DateTime.now().
  final DateTime simdi;

  late final List<int> kulupSirasi; // 6 rastgele kulup indeksi
  int tur = 0;
  int faz = 0; // 0 = oncelikli oyuncu, 1 = digeri
  final Set<int> alinan = {};
  final List<List<GencSecim>> kadrolar = [[], []];
  final List<int> bosSlot = [0, 0];
  bool bitti = false;

  GencKadroEngine(this.repo, {Random? rng, DateTime? simdi})
      : rng = rng ?? Random(),
        simdi = simdi ?? DateTime.now() {
    final idx = List<int>.generate(repo.kulupler.length, (i) => i)
      ..shuffle(this.rng);
    kulupSirasi = idx.take(gencTurSayisi).toList();
  }

  int firstPicker(int t) => t % 2; // tur 1: O1 once, tur 2: O2 once...
  int get simdiSecen => faz == 0 ? firstPicker(tur) : 1 - firstPicker(tur);

  GencKulup get kulup => repo.kulupler[kulupSirasi[tur]];

  double yas(int i) => repo.oyuncular[i].yas(simdi) ?? gencBosCeza;

  List<String> acikMevkiler(int s) {
    final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
    for (final p in kadrolar[s]) {
      sayim[p.poz] = sayim[p.poz]! + 1;
    }
    return gencFormation.keys
        .where((z) => sayim[z]! < gencFormation[z]!)
        .toList();
  }

  /// Bu kulup + acik mevki + aktif + dogum tarihli; min 3 harf; sebepli engel.
  /// Dogum yili/yas META'DA GOSTERILMEZ — tahmin konusu!
  List<GencAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final acik = acikMevkiler(simdiSecen);
    final basla = <GencAday>[], iceren = <GencAday>[];
    for (final i in kulup.havuz) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      String? neden;
      if (alinan.contains(i)) {
        neden = 'Alındı';
      } else if (!acik.contains(o.poz)) {
        neden = '${gencSlotAd[o.poz]} dolu';
      } else if (!o.aktif) {
        neden = 'Aktif değil';
      } else if (o.dogumTarihi.isEmpty) {
        neden = 'Doğum tarihi yok';
      }
      ((pos == 0 || apos == 0) ? basla : iceren).add(GencAday(i, neden));
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Secim: gecerliligi MOTOR dogrular (UI'a guvenilmez).
  bool sec(int idx) {
    if (bitti) return false;
    final o = repo.oyuncular[idx];
    if (!kulup.havuz.contains(idx)) return false;
    if (alinan.contains(idx)) return false;
    if (!acikMevkiler(simdiSecen).contains(o.poz)) return false;
    if (!o.aktif || o.dogumTarihi.isEmpty) return false;
    alinan.add(idx);
    kadrolar[simdiSecen].add(GencSecim(o.poz, idx));
    _ilerle();
    return true;
  }

  /// Sure doldu: slot bos kalir (+60 yas ceza sonda islenir).
  void sureDoldu() {
    if (bitti) return;
    bosSlot[simdiSecen]++;
    _ilerle();
  }

  void _ilerle() {
    if (faz == 0) {
      faz = 1;
    } else {
      faz = 0;
      tur++;
    }
    if (tur >= gencTurSayisi) bitti = true;
  }

  /// Secili oyuncularin yas toplami (ustte biriken sayi — ceza HARIC).
  double araToplam(int s) => kadrolar[s].fold(0.0, (a, p) => a + yas(p.idx));

  /// Nihai toplam: bos slotlar +60 ceza ile.
  double toplam(int s) =>
      araToplam(s) + (gencTurSayisi - kadrolar[s].length) * gencBosCeza;

  /// null = berabere, 0/1 = kazanan (GENC olan)
  int? kazanan() {
    final t0 = toplam(0), t1 = toplam(1);
    if ((t0 - t1).abs() < 0.001) return null;
    return t0 < t1 ? 0 : 1;
  }
}

/// Yas gosterimi: 1 ondalik, Turkce virgul (or. "19,3").
String yasStr(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
