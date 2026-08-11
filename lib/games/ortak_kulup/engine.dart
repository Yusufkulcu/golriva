import 'dart:math';
import '../../data/players_repository.dart';
import '../core/tr_norm.dart';

/// ORTAK KULÜP AVI motoru (Faz 2.18 — yeni oyun).
/// Her turda İKİ KULÜP gelir: sırayla, İKİSİNDE DE OYNAMIŞ bir futbolcu
/// yazılır. Doğru isim → söz rakibe geçer. YANLIŞ isim ya da süre dolumu →
/// TURU RAKİP ALIR. Ortak oyuncular tükenirse son doğru söyleyen turu alır.
/// 5 tur; çok tur alan maçı kazanır. Arama KÖRDÜR: aday listesi kulüp
/// bilgisi sızdırmaz — risk oyuncunun bilgisindedir.
/// Seed determinizmi: iki istemci aynı kulüp çiftlerini türetir.
const ortakTurSayisi = 5;
const ortakMinKesisim = 4; // çift seçim eşiği: en az 4 ortak oyuncu

class OrtakAday {
  final int idx;
  final String? neden; // null = secilebilir; "Söylendi"
  OrtakAday(this.idx, this.neden);
}

class OrtakKulupEngine {
  final PlayersRepository repo;
  final Random rng;

  late final List<(int, int)> ciftler; // tur başına kulüp çifti (idx)
  int tur = 0;
  late int aktor;
  final Set<int> soylenen = {}; // BU TURDA söylenmiş oyuncular
  int? sonSoyleyen; // bu turda son doğru söyleyen
  final List<int> skor = [0, 0];
  final List<int> turKazanani = [];
  final List<int> turSoylenenSayisi = [];
  bool bitti = false;

  OrtakKulupEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    // Geçerli çiftler: kesişimi yeterli tüm kulüp ikilileri.
    final adaylar = <(int, int)>[];
    for (var i = 0; i < repo.kulupler.length; i++) {
      final si = repo.kulupler[i].havuz.toSet();
      for (var j = i + 1; j < repo.kulupler.length; j++) {
        var ortak = 0;
        for (final x in repo.kulupler[j].havuz) {
          if (si.contains(x) && ++ortak >= ortakMinKesisim) break;
        }
        if (ortak >= ortakMinKesisim) adaylar.add((i, j));
      }
    }
    adaylar.shuffle(this.rng);
    ciftler = adaylar.take(ortakTurSayisi).toList();
    aktor = firstActor(0);
  }

  int firstActor(int t) => t % 2;
  Kulup get kulupA => repo.kulupler[ciftler[tur].$1];
  Kulup get kulupB => repo.kulupler[ciftler[tur].$2];

  /// Bu turda hâlâ söylenebilecek ortak oyuncu var mı?
  bool get ortakKaldi {
    final sb = kulupB.havuz.toSet();
    return kulupA.havuz
        .any((i) => sb.contains(i) && !soylenen.contains(i));
  }

  /// Min 3 harf; TÜM oyuncularda arar (kör mekanik — kulüp bilgisi
  /// meta'da YOK); ad-başı önce; en fazla 8; söylenmişler işaretli.
  List<OrtakAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <OrtakAday>[], iceren = <OrtakAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      final neden = soylenen.contains(i) ? 'Söylendi' : null;
      ((pos == 0 || apos == 0) ? basla : iceren).add(OrtakAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Aktörün seçimi. Dönüş: doğru muydu (geçersizde null).
  /// Doğru → söz rakibe; ortak tükenirse TURU AKTÖR ALIR (son söyleyen).
  /// Yanlış → TURU RAKİP ALIR.
  bool? sec(int idx) {
    if (bitti) return null;
    if (idx < 0 || idx >= repo.oyuncular.length) return null;
    if (soylenen.contains(idx)) return null; // UI zaten engeller
    final dogru = kulupA.havuz.contains(idx) && kulupB.havuz.contains(idx);
    if (!dogru) {
      _turuKapat(1 - aktor);
      return false;
    }
    soylenen.add(idx);
    sonSoyleyen = aktor;
    if (!ortakKaldi) {
      _turuKapat(aktor); // havuzu kurutan turu alır
      return true;
    }
    aktor = 1 - aktor;
    return true;
  }

  /// Süre dolumu = cevap yok → turu rakip alır.
  void sureDoldu() {
    if (bitti) return;
    _turuKapat(1 - aktor);
  }

  void _turuKapat(int kazananS) {
    skor[kazananS]++;
    turKazanani.add(kazananS);
    turSoylenenSayisi.add(soylenen.length);
    if (tur + 1 >= ortakTurSayisi) {
      bitti = true;
      return;
    }
    tur++;
    soylenen.clear();
    sonSoyleyen = null;
    aktor = firstActor(tur);
  }

  /// null = berabere (5 turda imkânsız ama korunur) · 0/1 = kazanan.
  int? kazanan() {
    if (skor[0] == skor[1]) return null;
    return skor[0] > skor[1] ? 0 : 1;
  }
}
