import 'dart:math';
import '../../data/serbest_repository.dart';
import '../core/tr_norm.dart';

/// SERBEST KADRO motoru — Mac Rekortmenleri & Milli Gol Krallari ortak motoru
/// (oyunlar/mac_rekortmenleri.html + milli_gol_krallari.html birebir cevirisi).
/// TUM havuzdan serbest secim (kulup kisiti yok), formasyon oyuna gore degisir:
/// Mac Rekortmenleri 1K-2D-2O-1F, Milli Gol Krallari 0K-2D-2O-2F.
/// Degerler secimde GORUNUR, YUKSEK toplam kazanir. Bos etap ceza yok
/// (0 katki zaten ceza). Oncelik her turda el degistirir; min 3 harf arama.
const serbestSlotAd = {'K': 'Kaleci', 'D': 'Defans', 'O': 'Orta', 'F': 'Forvet'};

class SerbestConfig {
  final Map<String, int> formation;
  final List<String> slotOrder;
  final String etiket; // "EN ÇOK MAÇ"
  final String birim; // "maç" / "gol"
  final String baslik; // "MAÇ REKORTMENLERİ"
  const SerbestConfig(
      {required this.formation,
      required this.slotOrder,
      required this.etiket,
      required this.birim,
      required this.baslik});
}

const macConfig = SerbestConfig(
    formation: {'K': 1, 'D': 2, 'O': 2, 'F': 1},
    slotOrder: ['K', 'D', 'D', 'O', 'O', 'F'],
    etiket: 'En Çok Maç Oynayan Oyuncu',
    birim: 'maç',
    baslik: 'MAÇ REKORTMENLERİ');
const milligolConfig = SerbestConfig(
    formation: {'K': 0, 'D': 2, 'O': 2, 'F': 2},
    slotOrder: ['D', 'D', 'O', 'O', 'F', 'F'],
    etiket: 'En Çok Milli Takım Golü Atan Oyuncu',
    birim: 'gol',
    baslik: 'MİLLİ TAKIM GOL KRALLARI');

const serbestTurSayisi = 6;

class SerbestAday {
  final int idx;
  final String? neden;
  SerbestAday(this.idx, this.neden);
}

class SerbestSecim {
  final String poz;
  final int idx;
  SerbestSecim(this.poz, this.idx);
}

class SerbestKadroEngine {
  final SerbestRepository repo;
  final SerbestConfig config;
  final Random rng;

  int tur = 0;
  int faz = 0;
  final Set<int> alinan = {};
  final List<List<SerbestSecim>> kadrolar = [[], []];
  final List<int> bosEtap = [0, 0];
  bool bitti = false;

  SerbestKadroEngine(this.repo, this.config, {Random? rng})
      : rng = rng ?? Random();

  int firstPicker(int t) => t % 2;
  int get simdiSecen => faz == 0 ? firstPicker(tur) : 1 - firstPicker(tur);

  List<String> acikMevkiler(int s) {
    final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
    for (final p in kadrolar[s]) {
      sayim[p.poz] = sayim[p.poz]! + 1;
    }
    return config.formation.keys
        .where((z) => sayim[z]! < config.formation[z]!)
        .toList();
  }

  /// Min 3 harf; TUM havuz; sebepli engeller: Alındı / mevki dolu.
  List<SerbestAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final acik = acikMevkiler(simdiSecen);
    final basla = <SerbestAday>[], iceren = <SerbestAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      String? neden;
      if (alinan.contains(i)) {
        neden = 'Alındı';
      } else if (!acik.contains(o.poz)) {
        neden = '${serbestSlotAd[o.poz]} dolu';
      }
      ((pos == 0 || apos == 0) ? basla : iceren).add(SerbestAday(i, neden));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  bool sec(int idx) {
    if (bitti) return false;
    final o = repo.oyuncular[idx];
    if (alinan.contains(idx)) return false;
    if (!acikMevkiler(simdiSecen).contains(o.poz)) return false;
    alinan.add(idx);
    kadrolar[simdiSecen].add(SerbestSecim(o.poz, idx));
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
    if (tur >= serbestTurSayisi) bitti = true;
  }

  int toplam(int s) =>
      kadrolar[s].fold(0, (a, p) => a + repo.oyuncular[p.idx].deger);

  /// null = berabere, 0/1 = kazanan (YUKSEK toplam)
  int? kazanan() {
    final t0 = toplam(0), t1 = toplam(1);
    if (t0 == t1) return null;
    return t0 > t1 ? 0 : 1;
  }
}
