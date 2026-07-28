import 'dart:math';
import '../../data/kor_av_repository.dart';
import '../core/tr_norm.dart';

/// KOR AV motoru — Bonservis Avi & Sari Kart Avi'nin ortak motoru
/// (kaynak_kod/bonservis_avi.html + sari_kart_avi.html birebir cevirisi).
/// Tek kategori kor hedef avi: N=4-6 futbolcu, hedef = top-N toplaminin
/// %40-65'i (formul v2, tam onluk). Degerler secimde GIZLI, sonda kademeli
/// acilir. Sure dolarsa hak yanar (0 sayilir). Hedefe MUTLAK yakin kazanir.

class KorAvAday {
  final int idx;
  final String? neden; // null = secilebilir; "Alındı"
  KorAvAday(this.idx, this.neden);
}

class KorAvEngine {
  final KorAvRepository repo;
  final Random rng;

  late final int kadroN; // 4-6
  late final int hedef;
  int sira = 0;
  final Set<int> alinan = {};
  final List<List<int>> secimler = [[], []];
  final List<int> yanan = [0, 0];
  bool bitti = false;

  KorAvEngine(this.repo, {Random? rng, int? sabitN}) : rng = rng ?? Random() {
    kadroN = sabitN ?? 4 + this.rng.nextInt(3);
    final maxN = repo.topDegerler[kadroN - 1];
    final lo = (0.40 * maxN / 10).ceil() * 10;
    final hi = (0.65 * maxN / 10).floor() * 10;
    hedef = lo + 10 * this.rng.nextInt(((hi - lo) ~/ 10) + 1);
    sira = this.rng.nextInt(2);
  }

  double deger(int i) => repo.oyuncular[i].deger;
  int kalanHak(int s) => kadroN - secimler[s].length - yanan[s];

  /// Min 3 harf; ad-basi once; en fazla 8; deger META'DA YOK (kor mekanik).
  List<KorAvAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <KorAvAday>[], iceren = <KorAvAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      final neden = alinan.contains(i) ? 'Alındı' : null;
      ((pos == 0 || apos == 0) ? basla : iceren).add(KorAvAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

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

  double toplam(int s) => secimler[s].fold(0.0, (a, i) => a + deger(i));
  double fark(int s) => (toplam(s) - hedef).abs();

  int? kazanan() {
    final f0 = fark(0), f1 = fark(1);
    if ((f0 - f1).abs() < 0.0001) return null;
    return f0 < f1 ? 0 : 1;
  }

  /// Kademeli acilis sirasi: satir satir, her satirda once O1 sonra O2.
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

/// Deger gosterimi: tam sayiysa "120", degilse "117,5" (TR virgul).
String korAvFmt(double v) => v % 1 == 0
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');
