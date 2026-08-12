import 'dart:math';
import '../../data/players_repository.dart';
import '../core/tr_norm.dart';

/// ORTAK KULÜP AVI motoru (Faz 2.18 · v2 — kullanıcı kararı).
/// Her turda İKİ KULÜP gelir: İKİSİNDE DE OYNAMIŞ bir futbolcu aranır.
/// v2 ÇEVRİMİÇİ: EŞ ZAMANLI YARIŞ — iki oyuncu da AYNI ANDA arar,
/// İLK DOĞRU YAZAN turu alır (sunucu hakemi: bayrak_kap, ilk kayıt kazanır).
/// Yanlış yazan O TUR KİLİTLENİR; ikisi de kilitlenirse ya da süre dolarsa
/// tur PUANSIZ kapanır. HOT-SEAT: tek cihazda sırayla (eski kural) —
/// doğru isim sözü devreder, yanlış/süre turu rakibe verir.
/// 5 tur; çok tur alan kazanır (puansız turlar yüzünden berabere olabilir).
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
  late int aktor; // yalnız HOT-SEAT sıra akışında kullanılır
  final Set<int> soylenen = {}; // BU TURDA söylenmiş oyuncular (hot-seat)
  final List<bool> kilitli = [false, false]; // YARIŞ modunda tur kilidi
  int? sonSoyleyen; // hot-seat: bu turda son doğru söyleyen
  final List<int> skor = [0, 0];
  final List<int?> turKazanani = []; // null = puansız tur (yarış modu)
  final List<int?> turBulunan = []; // kazanan ismin idx'i (gösterim)
  bool bitti = false;

  OrtakKulupEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    // Geçerli çiftler: kesişimi yeterli tüm kulüp ikilileri.
    final adaylarL = <(int, int)>[];
    for (var i = 0; i < repo.kulupler.length; i++) {
      final si = repo.kulupler[i].havuz.toSet();
      for (var j = i + 1; j < repo.kulupler.length; j++) {
        var ortak = 0;
        for (final x in repo.kulupler[j].havuz) {
          if (si.contains(x) && ++ortak >= ortakMinKesisim) break;
        }
        if (ortak >= ortakMinKesisim) adaylarL.add((i, j));
      }
    }
    adaylarL.shuffle(this.rng);
    ciftler = adaylarL.take(ortakTurSayisi).toList();
    aktor = firstActor(0);
  }

  int firstActor(int t) => t % 2;
  Kulup get kulupA => repo.kulupler[ciftler[tur].$1];
  Kulup get kulupB => repo.kulupler[ciftler[tur].$2];

  /// İki kulüpte de oynamış mı? (yarış + hot-seat doğrulaması)
  bool dogruMu(int idx) =>
      idx >= 0 &&
      idx < repo.oyuncular.length &&
      kulupA.havuz.contains(idx) &&
      kulupB.havuz.contains(idx);

  /// Bu turda hâlâ söylenebilecek ortak oyuncu var mı? (hot-seat)
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

  // ───────── YARIŞ MODU (çevrimiçi) ─────────

  /// [taraf] yanlış yazdı: o tur kilitlenir. İkisi de kilitlendiyse tur
  /// PUANSIZ kapanır (dönüş true = tur kapandı).
  bool yanlisla(int taraf) {
    if (bitti) return false;
    kilitli[taraf] = true;
    if (kilitli[0] && kilitli[1]) {
      turKapat(null, null);
      return true;
    }
    return false;
  }

  /// Turu kapat (yarış hakem kararı ya da süre dolumu):
  /// [kazananS] null = puansız; [bulunanIdx] kazanan ismin kaydı.
  void turKapat(int? kazananS, int? bulunanIdx) {
    if (bitti) return;
    if (kazananS != null) skor[kazananS]++;
    turKazanani.add(kazananS);
    turBulunan.add(bulunanIdx);
    if (tur + 1 >= ortakTurSayisi) {
      bitti = true;
      return;
    }
    tur++;
    soylenen.clear();
    kilitli[0] = false;
    kilitli[1] = false;
    sonSoyleyen = null;
    aktor = firstActor(tur);
  }

  // ───────── SIRA MODU (hot-seat — eski kural) ─────────

  /// Aktörün seçimi. Dönüş: doğru muydu (geçersizde null).
  /// Doğru → söz rakibe; ortak tükenirse TURU AKTÖR ALIR (son söyleyen).
  /// Yanlış → TURU RAKİP ALIR.
  bool? sec(int idx) {
    if (bitti) return null;
    if (idx < 0 || idx >= repo.oyuncular.length) return null;
    if (soylenen.contains(idx)) return null; // UI zaten engeller
    if (!dogruMu(idx)) {
      turKapat(1 - aktor, null);
      return false;
    }
    soylenen.add(idx);
    sonSoyleyen = aktor;
    if (!ortakKaldi) {
      turKapat(aktor, idx); // havuzu kurutan turu alır
      return true;
    }
    aktor = 1 - aktor;
    return true;
  }

  /// Hot-seat süre dolumu = cevap yok → turu rakip alır.
  void sureDoldu() {
    if (bitti) return;
    turKapat(1 - aktor, null);
  }

  /// null = berabere (yarışta puansız turlarla mümkün) · 0/1 = kazanan.
  int? kazanan() {
    if (skor[0] == skor[1]) return null;
    return skor[0] > skor[1] ? 0 : 1;
  }
}
