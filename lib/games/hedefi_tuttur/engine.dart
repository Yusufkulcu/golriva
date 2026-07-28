import 'dart:math';
import '../../data/hedef_repository.dart';
import '../core/tr_norm.dart';

/// HEDEFI TUTTUR motoru — kaynak_kod/hedefi_tuttur.html'in birebir Dart cevirisi.
/// Kurallar: rastgele kategori (14) + rastgele kadro boyu N (4-7);
/// HEDEF FORMULU v2: hedef = kategorinin top-N toplaminin %40-65'i, tam onluk
/// ("Bundesliga 900 gol" faciasi bir daha yasanamaz — hedef daima erisilebilir).
/// KOR mekanik: degerler secim sirasinda GOSTERILMEZ, sonda kademeli acilir.
/// Hic oynamamis biri 0 sayilir — tuzak mi strateji mi, oyuncuya kalmis.
/// Sure dolarsa hak yanar (0 sayilir). Hedefe MUTLAK FARKI kucuk olan kazanir.

class HedefAday {
  final int idx;
  final String? neden; // null = secilebilir; "Alındı"
  HedefAday(this.idx, this.neden);
}

class HedefiTutturEngine {
  final HedefRepository repo;
  final Random rng;

  late final int kadroN; // 4-7
  late final int katIdx;
  late final int hedef;
  int sira = 0;
  final Set<int> alinan = {};
  final List<List<int>> secimler = [[], []];
  final List<int> yanan = [0, 0];
  bool bitti = false;

  HedefiTutturEngine(this.repo, {Random? rng, int? sabitKatIdx, int? sabitN})
      : rng = rng ?? Random() {
    kadroN = sabitN ?? 4 + this.rng.nextInt(4);
    katIdx = sabitKatIdx ?? this.rng.nextInt(repo.kategoriler.length);
    final maxN = repo.topDegerler[katIdx][kadroN - 1];
    final lo = (0.40 * maxN / 10).ceil() * 10;
    final hi = (0.65 * maxN / 10).floor() * 10;
    hedef = lo + 10 * this.rng.nextInt(((hi - lo) ~/ 10) + 1);
    sira = this.rng.nextInt(2);
  }

  HedefKategori get kategori => repo.kategoriler[katIdx];
  int deger(int i) => repo.oyuncular[i].degerler[kategori.degerIdx];

  int kalanHak(int s) => kadroN - secimler[s].length - yanan[s];

  /// Min 3 harf; ad-basi once; en fazla 8; deger META'DA YOK (kor mekanik).
  List<HedefAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <HedefAday>[], iceren = <HedefAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      final neden = alinan.contains(i) ? 'Alındı' : null;
      ((pos == 0 || apos == 0) ? basla : iceren).add(HedefAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Secim: gecerliligi MOTOR dogrular (UI'a guvenilmez).
  bool sec(int idx) {
    if (bitti) return false;
    if (idx < 0 || idx >= repo.oyuncular.length) return false;
    if (alinan.contains(idx)) return false;
    if (kalanHak(sira) <= 0) return false;
    alinan.add(idx);
    secimler[sira].add(idx);
    _ilerle();
    return true;
  }

  /// Sure doldu: hak yanar, 0 sayilir.
  void sureDoldu() {
    if (bitti) return;
    yanan[sira]++;
    _ilerle();
  }

  void _ilerle() {
    sira = 1 - sira;
    if (kalanHak(sira) <= 0) sira = 1 - sira;
    if (kalanHak(0) <= 0 && kalanHak(1) <= 0) bitti = true;
  }

  int toplam(int s) => secimler[s].fold(0, (a, i) => a + deger(i));
  int fark(int s) => (toplam(s) - hedef).abs();

  /// null = berabere, 0/1 = hedefe yakin olan
  int? kazanan() {
    final f0 = fark(0), f1 = fark(1);
    if (f0 == f1) return null;
    return f0 < f1 ? 0 : 1;
  }

  /// Kademeli acilis sirasi: satir satir, her satirda once O1 sonra O2.
  /// (s, r) ciftleri — UI 700ms bekleyip 1000ms adimlarla acar, tik atlar.
  List<(int, int)> acilisSirasi() {
    final r = <(int, int)>[];
    for (var row = 0; row < kadroN; row++) {
      for (var s = 0; s < 2; s++) {
        if (row < secimler[s].length) r.add((s, row));
      }
    }
    return r;
  }
}
