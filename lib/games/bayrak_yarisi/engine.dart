import 'dart:math';
import '../../data/players_repository.dart';
import '../core/tr_norm.dart';

/// BAYRAK YARISI motoru — kaynak_kod/bayrak_yarisi.html'in birebir cevirisi.
/// 5 tur; her tur ELIT ULKE + ELIT KULUP cifti (en az 3 uygun oyuncu garantili,
/// ulke ve kulup tekrari yok). Kim once "KAP"arsa 10 sn'de o ulkeden o kulupte
/// oynamis oyuncu yazar. Yanlis/pas/sure → hak digerine gecer; o da bilemezse
/// tur bos. Cok tur alan kazanir. Online'da buzz farkli cihazlardan gelir —
/// bu hot-seat prototipte iki KAP butonu ayni ekranda (kullanici karari).
const bayrakTurSayisi = 5;
const bayrakRaceSn = 20;
const bayrakCevapSn = 10;

/// Elit ulkeler: (veri adi, TR gorunum adi). Bayrak EMOJISI KULLANILMAZ —
/// GOLRIVA kurali: emoji yasak, vektorel/tipografik gosterim.
const elitUlkeler = [
  ('Brazil', 'Brezilya'),
  ('Argentina', 'Arjantin'),
  ('France', 'Fransa'),
  ('Germany', 'Almanya'),
  ('Spain', 'İspanya'),
  ('Italy', 'İtalya'),
  ('England', 'İngiltere'),
  ('Portugal', 'Portekiz'),
  ('Netherlands', 'Hollanda'),
  ('Belgium', 'Belçika'),
  ('Croatia', 'Hırvatistan'),
  ('Uruguay', 'Uruguay'),
  ('Türkiye', 'Türkiye'),
  ('Senegal', 'Senegal'),
  ('Morocco', 'Fas'),
  ('Denmark', 'Danimarka'),
];

/// Veri iki yazimla geliyor: Turkey/Türkiye esle.
String ulkeNorm(String u) => u == 'Turkey' ? 'Türkiye' : u;

String ulkeTr(String en) {
  for (final (e, tr) in elitUlkeler) {
    if (e == en) return tr;
  }
  return en;
}

enum BayrakMod { race, answer, done }

class BayrakCift {
  final String ulke; // veri adi (en)
  final int kulupIdx;
  BayrakCift(this.ulke, this.kulupIdx);
}

class BayrakAday {
  final int idx;
  final String? neden; // null / "Alındı" / "Ülkesi farklı"
  BayrakAday(this.idx, this.neden);
}

class BayrakYarisiEngine {
  final PlayersRepository repo;
  final Random rng;

  late final List<BayrakCift> turlar;
  int tur = 0;
  BayrakMod mod = BayrakMod.race;
  int claimer = -1;
  final List<int> denenen = [];
  final Set<int> alinan = {};
  final List<int> skor = [0, 0];
  final List<int> gecmis = []; // -1 = bos tur, 0/1 = turu alan
  bool bitti = false;

  BayrakYarisiEngine(this.repo, {Random? rng}) : rng = rng ?? Random() {
    turlar = _ciftleriKur();
  }

  List<BayrakCift> _ciftleriKur() {
    // gecerli (ulke, kulup) ciftleri: en az 3 uygun oyuncu
    final pairs = <BayrakCift>[];
    for (var ci = 0; ci < repo.kulupler.length; ci++) {
      final sayim = <String, int>{};
      for (final i in repo.kulupler[ci].havuz) {
        final u = ulkeNorm(repo.oyuncular[i].ulke);
        sayim[u] = (sayim[u] ?? 0) + 1;
      }
      for (final (en, _) in elitUlkeler) {
        if ((sayim[en] ?? 0) >= 3) pairs.add(BayrakCift(en, ci));
      }
    }
    pairs.shuffle(rng);
    final out = <BayrakCift>[];
    final uK = <String>{}, cK = <int>{};
    for (final p in pairs) {
      if (uK.contains(p.ulke) || cK.contains(p.kulupIdx)) continue;
      out.add(p);
      uK.add(p.ulke);
      cK.add(p.kulupIdx);
      if (out.length == bayrakTurSayisi) break;
    }
    for (final p in pairs) {
      if (out.length >= bayrakTurSayisi) break;
      if (!out.contains(p)) out.add(p);
    }
    return out;
  }

  BayrakCift get cift => turlar[tur];
  Kulup get kulup => repo.kulupler[cift.kulupIdx];

  /// KAP: race modunda, daha once denememis oyuncu kapabilir.
  bool kap(int s) {
    if (bitti || mod != BayrakMod.race || denenen.contains(s)) return false;
    mod = BayrakMod.answer;
    claimer = s;
    denenen.add(s);
    return true;
  }

  /// Pas/sure/yanlis: hak duser. Donus: true = hak digerine gecti (otomatik
  /// kap), false = ikisi de denedi, tur bos kapandi.
  bool hakDus() {
    if (mod != BayrakMod.answer) return false;
    final diger = 1 - claimer;
    if (!denenen.contains(diger)) {
      mod = BayrakMod.race;
      kap(diger);
      return true;
    }
    _turKapat(-1);
    return false;
  }

  /// Kimse cesaret edemedi (race suresi doldu).
  void raceSuresiDoldu() {
    if (bitti || mod != BayrakMod.race) return;
    _turKapat(-1);
  }

  /// Min 3 harf; SADECE bu kulup havuzu; sebepli engeller.
  List<BayrakAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <BayrakAday>[], iceren = <BayrakAday>[];
    for (final i in kulup.havuz) {
      final o = repo.oyuncular[i];
      var pos = o.normAd.indexOf(nq);
      if (pos < 0 && o.normAlias.isNotEmpty) {
        pos = o.normAlias.contains(nq) ? 1 : -1;
      }
      if (pos < 0) continue;
      String? neden;
      if (alinan.contains(i)) {
        neden = 'Alındı';
      } else if (ulkeNorm(o.ulke) != cift.ulke) {
        neden = 'Ülkesi farklı';
      }
      (pos == 0 ? basla : iceren).add(BayrakAday(i, neden));
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// Dogru cevap secildi: turu claimer alir.
  bool dogru(int idx) {
    if (mod != BayrakMod.answer) return false;
    final o = repo.oyuncular[idx];
    if (!kulup.havuz.contains(idx)) return false;
    if (alinan.contains(idx)) return false;
    if (ulkeNorm(o.ulke) != cift.ulke) return false;
    alinan.add(idx);
    _turKapat(claimer);
    return true;
  }

  void _turKapat(int kazananS) {
    if (kazananS >= 0) skor[kazananS]++;
    gecmis.add(kazananS);
    mod = BayrakMod.done;
  }

  /// Bos turda gosterilecek ornek gecerli cevaplar (en fazla 3).
  List<String> ornekler() {
    final ex = <String>[];
    for (final i in kulup.havuz) {
      if (ulkeNorm(repo.oyuncular[i].ulke) == cift.ulke &&
          !alinan.contains(i)) {
        ex.add(repo.oyuncular[i].ad);
        if (ex.length == 3) break;
      }
    }
    return ex;
  }

  /// Sonraki tura gec (UI "done" gosteriminden sonra cagirir).
  void sonrakiTur() {
    if (mod != BayrakMod.done) return;
    tur++;
    if (tur >= bayrakTurSayisi) {
      bitti = true;
      return;
    }
    mod = BayrakMod.race;
    claimer = -1;
    denenen.clear();
  }

  /// null = berabere, 0/1 = kazanan (cok tur alan)
  int? kazanan() {
    if (skor[0] == skor[1]) return null;
    return skor[0] > skor[1] ? 0 : 1;
  }
}
