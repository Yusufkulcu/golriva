import 'dart:math';
import '../../data/kor_av_repository.dart';
import '../../data/players_repository.dart';
import '../core/tr_norm.dart';

/// KİM BU? motoru (Faz 2.18 — yeni oyun). İPUCU AÇIK ARTIRMASI:
/// Gizemli bir futbolcu seçilir; ipuçları TEK TEK açılır. Sıran geldiğinde
/// ya yeni ipucu açarsın (söz rakibe geçer) ya da TAHMİN edersin.
/// ERKEN bilen ÇOK puan alır: puan = ipucu sayısı + 1 - açık.
/// TEK TAHMİN HAKKIN VAR: yanlış tahmin = o tur KİLİTLENİRSİN; rakip tek
/// başına devam eder. İkisi de kilitlenirse tur puansız kapanır.
/// 2 tur (kullanıcı kararı: 5 çoktu), toplam puan kazanır.
/// v2: OYNADIĞI KULÜP ipucu — boy verisindeki kulüp havuzlarından çapraz
/// eşleme (ad+ülke); bulunamazsa o gizem kulüpsüz 7 ipucuyla oynanır.
/// Seed determinizmi: iki istemci aynı gizemli oyuncuları türetir.
const kimBuTurSayisi = 2;
// Gizem adayları: en değerli 150 (kullanıcı kararı: 400 fazla niş kaçıyordu,
// daha tanınmış/popüler isimler gelsin).
const kimBuHavuzN = 150;

class KimBuAday {
  final int idx;
  final String? neden; // null = secilebilir (meta GOSTERILMEZ — sizinti olur)
  KimBuAday(this.idx, this.neden);
}

class KimBuEngine {
  final KorAvRepository repo;
  final PlayersRepository? kulupRepo; // OYNADIĞI KULÜP ipucu kaynağı
  final Random rng;

  late final List<int> gizemler; // tur başına gizemli oyuncu idx
  late final List<String?> gizemKulupleri; // tur başına kulüp (null = yok)
  int tur = 0;
  int acik = 1; // açık ipucu sayısı (ilk ipucu peşin)
  late int aktor; // karar sırası kimde
  final List<bool> kilitli = [false, false];
  final List<int> skor = [0, 0];
  final List<int?> turKazanani = []; // null = puansız kapandı
  bool bitti = false;

  KimBuEngine(this.repo, {this.kulupRepo, Random? rng})
      : rng = rng ?? Random() {
    // Gizem havuzu: en değerli N oyuncu (tanınırlık) + temiz veri.
    final sirali = List<int>.generate(repo.oyuncular.length, (i) => i)
      ..sort((a, b) =>
          repo.oyuncular[b].deger.compareTo(repo.oyuncular[a].deger));
    final havuz = sirali
        .where((i) {
          final o = repo.oyuncular[i];
          return o.deger > 0 && o.dogumYili > 0 && o.ulke.isNotEmpty;
        })
        .take(kimBuHavuzN)
        .toList()
      ..shuffle(this.rng);
    gizemler = havuz.take(kimBuTurSayisi).toList();
    gizemKulupleri = [
      for (final g in gizemler) _kulupBul(repo.oyuncular[g])
    ];
    aktor = firstActor(0);
  }

  /// Boy verisinde ad+ülke eşleşmesiyle oyuncuyu bul, oynadığı İLK kulübü
  /// döndür (kulüp listesi sırası — iki istemcide de DETERMİNİSTİK).
  String? _kulupBul(KorAvOyuncu o) {
    final kr = kulupRepo;
    if (kr == null) return null;
    for (var i = 0; i < kr.oyuncular.length; i++) {
      final b = kr.oyuncular[i];
      if (b.normAd == o.normAd && b.ulke == o.ulke) {
        for (final k in kr.kulupler) {
          if (k.havuz.contains(i)) return k.ad;
        }
      }
    }
    return null;
  }

  int firstActor(int t) => t % 2;
  KorAvOyuncu get gizem => repo.oyuncular[gizemler[tur]];

  /// İpucu metinleri — sabit sıra: kimlik daralması her adımda hissedilir.
  /// Kulüp bulunabildiyse 8, yoksa 7 ipucu.
  List<(String, String)> tumIpuclari() {
    final o = gizem;
    final duzAd = o.ad.replaceAll(' ', '').replaceAll('-', '');
    final kulup = gizemKulupleri[tur];
    return [
      ('MEVKİ', o.mevkiAd),
      ('DOĞUM YILI', '${o.dogumYili}'),
      ('ÜLKE', o.ulke),
      if (kulup != null) ('OYNADIĞI KULÜP', kulup),
      ('BONSERVİS', '${korAvVal(o.deger)} M€'),
      ('AD UZUNLUĞU', '${duzAd.length} harf'),
      ('İLK HARF', o.ad.substring(0, 1).toUpperCase()),
      ('İLK 3 HARF', o.ad.length >= 3 ? o.ad.substring(0, 3) : o.ad),
    ];
  }

  List<(String, String)> acikIpuclari() =>
      tumIpuclari().take(acik).toList();

  /// Bu turun toplam ipucu sayısı (7 ya da 8 — kulübe bağlı).
  int get ipucuSayisi => tumIpuclari().length;

  bool get ipucuKaldi => acik < ipucuSayisi;

  /// Doğru tahmine yazılacak puan: erken bilen çok alır.
  int get turPuani => ipucuSayisi + 1 - acik;

  /// Yeni ipucu aç: söz rakibe geçer (rakip kilitliyse bende kalır).
  /// İpucu kalmadıysa false (UI butonu zaten kapatır).
  bool ipucuAc() {
    if (bitti || !ipucuKaldi) return false;
    acik++;
    _sozuDevret();
    return true;
  }

  /// Tahmin: doğruysa tur biter (puan aktöre), yanlışsa aktör KİLİTLENİR.
  /// Dönüş: doğru muydu (geçersiz durumda null).
  bool? tahmin(int idx) {
    if (bitti || kilitli[aktor]) return null;
    if (idx < 0 || idx >= repo.oyuncular.length) return null;
    if (idx == gizemler[tur]) {
      skor[aktor] += turPuani;
      _turuKapat(aktor);
      return true;
    }
    kilitli[aktor] = true;
    if (kilitli[0] && kilitli[1]) {
      _turuKapat(null);
    } else {
      aktor = 1 - aktor; // rakip tek başına devam eder
    }
    return false;
  }

  /// Süre dolumu: ipucu kaldıysa otomatik AÇ; kalmadıysa PAS (= kilit).
  void sureDoldu() {
    if (bitti) return;
    if (ipucuKaldi) {
      ipucuAc();
      return;
    }
    kilitli[aktor] = true;
    if (kilitli[0] && kilitli[1]) {
      _turuKapat(null);
    } else {
      aktor = 1 - aktor;
    }
  }

  void _sozuDevret() {
    final diger = 1 - aktor;
    if (!kilitli[diger]) aktor = diger;
    // rakip kilitliyse söz bende kalır (solo)
  }

  void _turuKapat(int? kazananS) {
    turKazanani.add(kazananS);
    if (tur + 1 >= kimBuTurSayisi) {
      bitti = true;
      return;
    }
    tur++;
    acik = 1;
    kilitli[0] = false;
    kilitli[1] = false;
    aktor = firstActor(tur);
  }

  /// Min 3 harf; ad-başı önce; en fazla 8. META GÖSTERİLMEZ:
  /// mevki/ülke listede görünse ipuçlarıyla çapraz elenirdi (sızıntı).
  List<KimBuAday> adaylar(String sorgu) {
    final nq = trNorm(sorgu);
    if (nq.length < 3) return [];
    final basla = <KimBuAday>[], iceren = <KimBuAday>[];
    for (var i = 0; i < repo.oyuncular.length; i++) {
      final o = repo.oyuncular[i];
      final pos = o.normAd.indexOf(nq);
      final apos = o.normAlias.isEmpty ? -1 : o.normAlias.indexOf(nq);
      if (pos < 0 && apos < 0) continue;
      ((pos == 0 || apos == 0) ? basla : iceren).add(KimBuAday(i, null));
      if (basla.length >= 8) break;
    }
    return [...basla, ...iceren].take(8).toList();
  }

  /// null = berabere · 0/1 = toplam puanı yüksek olan.
  int? kazanan() {
    if (skor[0] == skor[1]) return null;
    return skor[0] > skor[1] ? 0 : 1;
  }
}

/// Değer gösterimi: tam sayıysa "120", değilse "117,5" (TR virgül).
String korAvVal(double v) => v % 1 == 0
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');
