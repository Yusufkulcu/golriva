import 'dart:math';
import '../../data/players_repository.dart';
import '../core/tr_norm.dart';

/// EN KISA KADRO motoru — oyunlar/en_kisa_kadro.html'in birebir Dart cevirisi.
/// Kurallar (guncel — kullanici istegi): 6 tur = 6 LIG (5 buyuk lig + Super
/// Lig, rastgele sirayla; kulup/ulke YOK — kisa oyuncu bulmak cok zordu);
/// 1K-2D-2O-1F;
/// kap-kac ("Alindi"), boysuzlar engelli ("Boy verisi yok"); dusuk toplam kazanir;
/// bos slot +210 cm ceza; oncelik her turda el degistirir; min 3 harf arama.
const formation = {'K': 1, 'D': 2, 'O': 2, 'F': 1};
const slotOrder = ['K', 'D', 'D', 'O', 'O', 'F'];
const slotAd = {'K': 'Kaleci', 'D': 'Defans', 'O': 'Orta', 'F': 'Forvet'};
const bosCeza = 210;
const turSayisi = 6;

class TurKaynak {
  final bool ligMi;
  final int index; // kulup ya da lig indeksi
  TurKaynak(this.ligMi, this.index);
}

class Aday {
  final int idx;
  final String? neden; // null = secilebilir; "Alındı" / "X dolu" / "Boy verisi yok"
  Aday(this.idx, this.neden);
}

class Secim {
  final String poz;
  final int idx;
  Secim(this.poz, this.idx);
}

class EnKisaKadroEngine {
  final PlayersRepository repo;
  final Random rng;

  late List<TurKaynak> turlar;
  int tur = 0;
  int faz = 0; // 0 = oncelikli oyuncu, 1 = digeri
  final Set<int> alinan = {};
  final List<List<Secim>> kadrolar = [[], []];
  final List<int> bosSlot = [0, 0];
  bool bitti = false;

  EnKisaKadroEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    turlar = _turlariKur();
  }

  /// 6 tur = 6 LIG (5 buyuk lig + Super Lig), rastgele sirayla — kullanici
  /// istegi: kulup/ulke havuzlarinda KISA oyuncu bulmak cok zordu; genis lig
  /// havuzlari oyunu oynanabilir kiliyor. Lig sayisi 6'dan azsa dongusel.
  List<TurKaynak> _turlariKur() {
    final li = List<int>.generate(repo.ligler.length, (i) => i)..shuffle(rng);
    return [
      for (var t = 0; t < turSayisi; t++) TurKaynak(true, li[t % li.length])
    ];
  }

  int firstPicker(int t) => t % 2; // tur 1: O1 once, tur 2: O2 once...
  int get simdiSecen => faz == 0 ? firstPicker(tur) : 1 - firstPicker(tur);

  List<int> get havuz => repo.ligler[turlar[tur].index].havuz;

  String get kaynakAdi => repo.ligler[turlar[tur].index].ad;

  List<String> acikMevkiler(int s) {
    final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
    for (final p in kadrolar[s]) {
      sayim[p.poz] = sayim[p.poz]! + 1;
    }
    return formation.keys.where((z) => sayim[z]! < formation[z]!).toList();
  }

  /// Min 3 harf; once ad-basi eslesenler, sonra icerenler; en fazla 8 sonuc.
  /// Engeller SEBEPLI gosterilir (sessiz engel yasak — proje ilkesi).
  List<Aday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final acik = acikMevkiler(simdiSecen);
    final basla = <Aday>[], iceren = <Aday>[];
    for (final i in havuz) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      String? neden;
      if (alinan.contains(i)) {
        neden = 'Alındı';
      } else if (!acik.contains(o.poz)) {
        neden = '${slotAd[o.poz]} dolu';
      } else if (o.boyCm <= 0) {
        neden = 'Boy verisi yok';
      }
      ((pos == 0 || apos == 0) ? basla : iceren).add(Aday(i, neden));
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Secim: gecerliligi MOTOR dogrular (UI'a guvenilmez).
  bool sec(int idx) {
    if (bitti) return false;
    final o = repo.oyuncular[idx];
    if (!havuz.contains(idx)) return false;
    if (alinan.contains(idx)) return false;
    if (!acikMevkiler(simdiSecen).contains(o.poz)) return false;
    if (o.boyCm <= 0) return false;
    alinan.add(idx);
    kadrolar[simdiSecen].add(Secim(o.poz, idx));
    _ilerle();
    return true;
  }

  /// Sure doldu: slot bos kalir (+210 ceza sonda islenir).
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
    if (tur >= turSayisi) bitti = true;
  }

  int toplam(int s) =>
      kadrolar[s].fold(0, (a, p) => a + repo.oyuncular[p.idx].boyCm) +
      (turSayisi - kadrolar[s].length) * bosCeza;

  /// null = berabere, 0/1 = kazanan (KISA olan)
  int? kazanan() {
    final t0 = toplam(0), t1 = toplam(1);
    if (t0 == t1) return null;
    return t0 < t1 ? 0 : 1;
  }
}
