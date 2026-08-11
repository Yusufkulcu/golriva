import 'dart:math';
import '../../data/ikiz_repository.dart';
import '../core/tr_norm.dart';

/// ŞL GECESİ motoru (Faz 2.18 — yeni oyun).
/// Şampiyonlar Ligi temalı kör seçim: 5 turun her birinin KATEGORİSİ var —
/// ŞL GOLÜ ya da ŞL ASİSTİ. Sırayla futbolcu seçilir; seçilenin O
/// KATEGORİDEKİ ŞL sayısı AÇILIR ve toplamına eklenir. Aynı futbolcu
/// maçta bir kez seçilebilir. Toplamı YÜKSEK olan kazanır.
/// Öncelik her turda el değiştirir (draft kuralı).
/// Seed determinizmi: iki istemci aynı kategori dizisini türetir.
const slTurSayisi = 5;

enum SlKategori { gol, asist }

class SlAday {
  final int idx;
  final String? neden; // null = secilebilir; "Alındı"
  SlAday(this.idx, this.neden);
}

class SlGecesiEngine {
  final IkizRepository repo;
  final Random rng;

  late final List<SlKategori> kategoriler;
  int tur = 0;
  int faz = 0; // 0 = öncelikli seçen, 1 = diğeri
  final Set<int> alinan = {};
  final List<List<(int, int)>> secimler = [[], []]; // (oyuncuIdx, katkı)
  final List<int> bosEtap = [0, 0];
  bool bitti = false;

  SlGecesiEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    // Kategori dizisi: 3 GOL + 2 ASİST, sırası seed'e göre karışık.
    final k = <SlKategori>[
      SlKategori.gol,
      SlKategori.gol,
      SlKategori.gol,
      SlKategori.asist,
      SlKategori.asist,
    ]..shuffle(this.rng);
    kategoriler = k;
  }

  int firstPicker(int t) => t % 2;
  int get simdiSecen => faz == 0 ? firstPicker(tur) : 1 - firstPicker(tur);
  SlKategori get kategori => kategoriler[tur];
  String get kategoriAd =>
      kategori == SlKategori.gol ? 'ŞL GOLÜ' : 'ŞL ASİSTİ';

  int katki(int idx) {
    final o = repo.oyuncular[idx];
    return kategori == SlKategori.gol ? o.clGol : o.clAsist;
  }

  /// Min 3 harf; ad-başı önce; en fazla 8; ŞL sayıları META'DA YOK
  /// (kör mekanik — kimin ŞL'de patladığını bilmek oyunun kendisi).
  List<SlAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <SlAday>[], iceren = <SlAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      final neden = alinan.contains(i) ? 'Alındı' : null;
      ((pos == 0 || apos == 0) ? basla : iceren).add(SlAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Sıradaki oyuncu bir futbolcu seçer; kategori katkısı açılıp eklenir.
  bool sec(int idx) {
    if (bitti) return false;
    if (idx < 0 || idx >= repo.oyuncular.length) return false;
    if (alinan.contains(idx)) return false;
    alinan.add(idx);
    secimler[simdiSecen].add((idx, katki(idx)));
    _ilerle();
    return true;
  }

  /// Süre dolumu: etap boş geçer (0 katkı).
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
    if (tur >= slTurSayisi) bitti = true;
  }

  int toplam(int s) => secimler[s].fold(0, (a, p) => a + p.$2);

  /// null = berabere · 0/1 = kazanan (YÜKSEK toplam).
  int? kazanan() {
    final t0 = toplam(0), t1 = toplam(1);
    if (t0 == t1) return null;
    return t0 > t1 ? 0 : 1;
  }
}
