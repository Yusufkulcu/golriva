import 'dart:math';
import '../../data/kupa_repository.dart';
import '../core/tr_norm.dart';

/// KUPA DRAFTI motoru — kaynak_kod/kupa_drafti.html'in birebir Dart cevirisi.
/// 6 tur, her tur rastgele KULUP; 1K-2D-2O-1F; o kulupte oynamis oyuncu secilir;
/// deger = kariyer KUPA sayisi, secimde ANINDA gorunur; YUKSEK toplam kazanir.
/// Bos etap ceza yok (0 katki). Oncelik her turda el degistirir; min 3 harf.
const kupaFormation = {'K': 1, 'D': 2, 'O': 2, 'F': 1};
const kupaSlotOrder = ['K', 'D', 'D', 'O', 'O', 'F'];
const kupaSlotAd = {'K': 'Kaleci', 'D': 'Defans', 'O': 'Orta', 'F': 'Forvet'};
const kupaTurSayisi = 6;

class KupaAday {
  final int idx;
  final String? neden;
  final bool aliastan; // eşleşme görünen addan değil TAM ADDAN geldi
  KupaAday(this.idx, this.neden, {this.aliastan = false});
}

class KupaSecim {
  final String poz;
  final int idx;
  KupaSecim(this.poz, this.idx);
}

class KupaDraftEngine {
  final KupaRepository repo;
  final Random rng;

  late final List<int> kulupSirasi;
  int tur = 0;
  int faz = 0;
  final Set<int> alinan = {};
  final List<List<KupaSecim>> kadrolar = [[], []];
  final List<int> bosEtap = [0, 0];
  bool bitti = false;

  KupaDraftEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    final idx = List<int>.generate(repo.kulupler.length, (i) => i)
      ..shuffle(this.rng);
    kulupSirasi = idx.take(kupaTurSayisi).toList();
  }

  int firstPicker(int t) => t % 2;
  int get simdiSecen => faz == 0 ? firstPicker(tur) : 1 - firstPicker(tur);
  KupaKulup get kulup => repo.kulupler[kulupSirasi[tur]];

  List<String> acikMevkiler(int s) {
    final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
    for (final p in kadrolar[s]) {
      sayim[p.poz] = sayim[p.poz]! + 1;
    }
    return kupaFormation.keys
        .where((z) => sayim[z]! < kupaFormation[z]!)
        .toList();
  }

  /// Bu kulup + acik mevki; min 3 harf; sebepli engeller.
  /// Kupa sayisi META'DA GOSTERILMEZ — tahmin konusu (secince acilir).
  /// v4.1: alias da aranir ("CR7" gibi takma adlar draft'ta calisir).
  /// v4.2: alias eslesmesi yalniz KELIME BASINDA ("juni" → "Junior" tamam,
  /// "uni" ortadan eslesip alakasiz isim getirmez) ve ekran aliastan
  /// eslesenlerde TAM ADI gosterir — baglantisiz isim karmasasi biter.
  List<KupaAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final acik = acikMevkiler(simdiSecen);
    final basla = <KupaAday>[], iceren = <KupaAday>[];
    for (final i in kulup.havuz) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final aliasVar = o.normAlias.isNotEmpty &&
          (o.normAlias.startsWith(nq) || o.normAlias.contains(' $nq'));
      if (pos < 0 && !aliasVar) continue;
      String? neden;
      if (alinan.contains(i)) {
        neden = 'Alındı';
      } else if (!acik.contains(o.poz)) {
        neden = '${kupaSlotAd[o.poz]} dolu';
      }
      final aday = KupaAday(i, neden, aliastan: pos < 0);
      ((pos == 0 || aliasVar) ? basla : iceren).add(aday);
    }
    return [...basla, ...iceren].take(8).toList();
  }

  bool sec(int idx) {
    if (bitti) return false;
    final o = repo.oyuncular[idx];
    if (!kulup.havuz.contains(idx)) return false;
    if (alinan.contains(idx)) return false;
    if (!acikMevkiler(simdiSecen).contains(o.poz)) return false;
    alinan.add(idx);
    kadrolar[simdiSecen].add(KupaSecim(o.poz, idx));
    _ilerle();
    return true;
  }

  void sureDoldu() {
    if (bitti) return;
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
    if (tur >= kupaTurSayisi) bitti = true;
  }

  int toplam(int s) =>
      kadrolar[s].fold(0, (a, p) => a + repo.oyuncular[p.idx].kupa);

  /// null = berabere, 0/1 = kazanan (YUKSEK kupa toplami)
  int? kazanan() {
    final t0 = toplam(0), t1 = toplam(1);
    if (t0 == t1) return null;
    return t0 > t1 ? 0 : 1;
  }
}
