import 'dart:math';
import '../../data/kor_av_repository.dart';
import '../core/tr_norm.dart';

/// BONSERVİS 21'İ motoru (Faz 2.17 — yeni oyun).
/// Blackjack gerilimli kör av: hedefe EN ÇOK YAKLAŞAN kazanır ama hedefi
/// AŞAN YANAR. Sırayla oyuncu seçilir (bonservis seçimde AÇILIR ve toplama
/// eklenir) ya da DUR denir. Duran bir daha seçemez; diğeri tek başına devam
/// eder. İkisi de durunca (ya da yanınca) maç biter.
/// Kazanan: yanmayan > az aşan; ikisi de sağlamsa hedefe mutlak yakın olan.
/// Seed determinizmi: iki istemci aynı hedefi ve ilk sırayı türetir.
const yirmibirMaxSecim = 8; // emniyet: 8 seçimden sonra otomatik DUR

class YirmibirAday {
  final int idx;
  final String? neden; // null = seçilebilir; "Alındı"
  YirmibirAday(this.idx, this.neden);
}

class YirmibirEngine {
  final KorAvRepository repo;
  final Random rng;

  late final int hedef;
  int sira = 0; // karar sırası kimde
  final Set<int> alinan = {};
  final List<List<int>> secimler = [[], []];
  final List<bool> durdu = [false, false];
  final List<bool> yandi = [false, false];
  bool bitti = false;

  YirmibirEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    // Hedef: top-6 toplamının %8-45'i, tam onluk — "ortaya karışık":
    // bir maçta 60M, ertesinde 400M olabilir; asıl gerilim AŞMAMAKTA.
    final maxN = repo.topDegerler[5];
    var lo = (0.08 * maxN / 10).ceil() * 10;
    var hi = (0.45 * maxN / 10).floor() * 10;
    if (lo < 10) lo = 10;
    if (hi < lo) hi = lo;
    hedef = lo + 10 * this.rng.nextInt(((hi - lo) ~/ 10) + 1);
    sira = this.rng.nextInt(2);
  }

  double deger(int i) => repo.oyuncular[i].deger;
  double toplam(int s) => secimler[s].fold(0.0, (a, i) => a + deger(i));
  bool aktif(int s) => !durdu[s];

  /// Min 3 harf; ad-başı önce; en fazla 8; DEĞER META'DA YOK (kör mekanik —
  /// oyuncunun bonservisini bilmek oyunun kendisi).
  List<YirmibirAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <YirmibirAday>[], iceren = <YirmibirAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      final neden = alinan.contains(i) ? 'Alındı' : null;
      ((pos == 0 || apos == 0) ? basla : iceren).add(YirmibirAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Sıradaki oyuncu bir futbolcu çeker. Geçerliyse toplama eklenir;
  /// hedef aşılırsa ÇEKEN YANAR (otomatik durur) ve sıra akışı ilerler.
  bool sec(int idx) {
    if (bitti || durdu[sira]) return false;
    if (idx < 0 || idx >= repo.oyuncular.length) return false;
    if (alinan.contains(idx)) return false;
    alinan.add(idx);
    secimler[sira].add(idx);
    if (toplam(sira) > hedef) {
      yandi[sira] = true;
      durdu[sira] = true;
    } else if (secimler[sira].length >= yirmibirMaxSecim) {
      durdu[sira] = true; // emniyet tavanı
    }
    _ilerle();
    return true;
  }

  /// Sıradaki oyuncu eli kapatır ("DUR"). Süre dolunca da bu çağrılır.
  void dur() {
    if (bitti || durdu[sira]) return;
    durdu[sira] = true;
    _ilerle();
  }

  void _ilerle() {
    if (durdu[0] && durdu[1]) {
      bitti = true;
      return;
    }
    final diger = 1 - sira;
    if (!durdu[diger]) {
      sira = diger; // klasik sıra değişimi
    } else if (durdu[sira]) {
      // ben de kapandıysam (imkansız değil: yanma anı) — bitti yukarıda yakalanır
    }
    // diğeri durduysa ve ben aktifsem sıra bende kalır (solo devam)
  }

  double fark(int s) => (toplam(s) - hedef).abs();

  /// null = berabere · 0/1 = kazanan.
  /// Kural: yanmayan yanana karşı kazanır; ikisi de aynı durumdaysa
  /// hedefe MUTLAK yakın olan kazanır; eşitse berabere.
  int? kazanan() {
    if (yandi[0] != yandi[1]) return yandi[0] ? 1 : 0;
    final f0 = fark(0), f1 = fark(1);
    if ((f0 - f1).abs() < 0.0001) return null;
    return f0 < f1 ? 0 : 1;
  }
}
