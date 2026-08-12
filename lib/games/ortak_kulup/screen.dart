import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/players_repository.dart';
import '../../online/mac_kanali.dart';
import '../../online/online_servis.dart';
import '../../online/hata_raporu.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// ORTAK KULÜP AVI ekranı (Faz 2.18 · v2) — iki kulüpte de oynamış futbolcu.
/// ÇEVRİMİÇİ: EŞ ZAMANLI YARIŞ — aynı çift, iki oyuncu da aynı anda arar,
/// İLK DOĞRU YAZAN turu alır (sunucu hakemi bayrak_kap: ilk kayıt kazanır).
/// Yanlış yazan o tur kilitlenir. HOT-SEAT: tek cihazda sırayla (eski kural).
/// RESPONSIVE KURAL: kök yerleşim ListView.
class OrtakKulupScreen extends StatefulWidget {
  final PlayersRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const OrtakKulupScreen({super.key, required this.repo, this.online});

  @override
  State<OrtakKulupScreen> createState() => _OrtakKulupScreenState();
}

class _OrtakKulupScreenState extends State<OrtakKulupScreen> {
  late OrtakKulupEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<OrtakAday> adaylar = [];
  String? uyari;
  bool uyariKotu = false;
  bool _hakemde = false; // yarış: sunucu kararı bekleniyor
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = 20;
  int _sayacTuru = 0;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  bool get yaris => widget.online != null;
  int get turSn => yaris ? 30 : 20;
  int get benimSeat =>
      yaris ? widget.online!.bilgi.benimSiram : engine.aktor;

  /// Yazabilir miyim? Yarışta: kilitli değilsem. Hot-seat: her zaman
  /// (sıradaki oyuncu cihazda).
  bool get yazabilirim => !engine.bitti &&
      !_hakemde &&
      (!yaris || !engine.kilitli[widget.online!.bilgi.benimSiram]);

  @override
  void initState() {
    super.initState();
    final o = widget.online;
    adlar = o == null
        ? ['Sen', 'Rakip']
        : (o.bilgi.benimSiram == 0
            ? ['Sen', o.bilgi.rakipAdi]
            : [o.bilgi.rakipAdi, 'Sen']);
    engine = OrtakKulupEngine(widget.repo,
        rng: o == null ? null : Random(o.bilgi.seed));
    o?.basla(_rakipHamle, onMacKapandi: _macKapandi);
    _sayacBaslat();
  }

  /// Rakip çekildi ya da maç sunucuda kapandı.
  void _macKapandi() {
    if (!mounted || _kapanisIslendi) return;
    if (engine.bitti) {
      if (!_sonucAcik) _sonucGoster(); // kurtarma ağı
      return;
    }
    _kapanisIslendi = true;
    sayac?.cancel();
    _hukmenTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: GolrivaColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: GolrivaColors.edge)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('RAKİP ÇEKİLDİ',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: GolrivaColors.goldHi,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              OnlineSonucButonlari(
                  kanal: widget.online!,
                  kazananSeat: widget.online!.bilgi.benimSiram),
            ]),
          ),
        ),
      ),
    );
  }

  void _rakipHamle(Map<String, dynamic> h) {
    if (!mounted || engine.bitti) return;
    _hukmenTimer?.cancel();
    final tip = h['tip'];
    if (tip == 'cekildi') {
      _macKapandi();
      return;
    }
    if (tip != 'tursonuc' && tip != 'yanlis') return;
    final hTur = (h['tur'] as num?)?.toInt() ?? -1;
    if (hTur != engine.tur) return; // tur zaten kapandı — yoksay
    setState(() {
      if (tip == 'tursonuc') {
        final kz = h['kazanan'] == null ? null : (h['kazanan'] as num).toInt();
        final idx = h['idx'] == null ? null : (h['idx'] as num).toInt();
        _turSonucIsle(kz, idx);
      } else {
        // rakip yanlış yazdı
        final rakipSeat = 1 - widget.online!.bilgi.benimSiram;
        final kapandi = engine.yanlisla(rakipSeat);
        if (kapandi) {
          uyariKotu = true;
          uyari = 'İkiniz de yanıldınız — tur puansız kapandı';
        } else {
          uyariKotu = false;
          uyari = 'Rakip yanıldı ve kilitlendi — sahne senin!';
        }
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
  }

  /// Tur sonucunu işle + metin (iki istemcide de aynı).
  void _turSonucIsle(int? kazananSeat, int? idx) {
    if (kazananSeat == null) {
      engine.turKapat(null, null);
      uyariKotu = true;
      uyari = 'Süre doldu — kimse bulamadı, tur puansız';
    } else {
      engine.turKapat(kazananSeat, idx);
      final ad = idx == null ? '' : ' (${widget.repo.oyuncular[idx].ad})';
      uyariKotu = false;
      uyari = 'Turu ${adlar[kazananSeat]} aldı$ad — ilk doğru yazan!';
    }
  }

  void _adimSonrasi() {
    if (engine.bitti) {
      sayac?.cancel();
      _sonucGoster();
    } else if (_sayacTuru != engine.tur) {
      _sayacTuru = engine.tur;
      _sayacBaslat();
    }
  }

  void _sayacBaslat() {
    sayac?.cancel();
    kalanSn = turSn;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        if (yaris) {
          _yarisZamanDoldu();
        } else {
          // hot-seat: süre = turu rakip alır (eski kural)
          setState(() {
            final aktor = engine.aktor;
            engine.sureDoldu();
            uyariKotu = true;
            uyari =
                '${adlar[aktor]} süreyi doldurdu — turu ${adlar[1 - aktor]} aldı';
            aramaCtrl.clear();
            adaylar = [];
          });
          _adimSonrasi();
        }
      }
    });
  }

  /// Yarışta süre dolumu: sunucu hakemine BOŞ kaydı önerilir — biri son
  /// anda kapmışsa hakem onu döndürür (ilk kayıt kazanır).
  Future<void> _yarisZamanDoldu() async {
    if (engine.bitti || _hakemde) return;
    final turNo = engine.tur;
    _hakemde = true;
    try {
      final r = await OnlineServis()
          .bayrakKap(widget.online!.bilgi.macId, turNo, bosMu: true);
      if (!mounted || engine.bitti || engine.tur != turNo) return;
      setState(() {
        _hakemde = false;
        if (r.sahip != null) {
          final seat = r.sahip == widget.online!.bilgi.p1Uid ? 0 : 1;
          _turSonucIsle(seat, null);
        } else {
          _turSonucIsle(null, null);
        }
        aramaCtrl.clear();
        adaylar = [];
      });
      _adimSonrasi();
    } catch (e, s) {
      _hakemde = false;
      hataBildir('ortak.zaman', e, s);
      // ağ hatası: kısa süre sonra tekrar dene
      if (mounted && !engine.bitti) {
        Timer(const Duration(seconds: 2), _yarisZamanDoldu);
      }
    }
  }

  Future<void> _sec(OrtakAday a) async {
    if (a.neden != null || !yazabilirim) return;
    final idx = a.idx;
    final ad = widget.repo.oyuncular[idx].ad;
    if (!yaris) {
      _hotSeatSec(idx, ad);
      return;
    }
    final turNo = engine.tur;
    if (!engine.dogruMu(idx)) {
      // YANLIŞ: bu tur kilitlendim
      setState(() {
        widget.online!.gonder({'tip': 'yanlis', 'tur': turNo});
        final kapandi = engine.yanlisla(benimSeat);
        uyariKotu = true;
        uyari = kapandi
            ? '$ad iki kulüpte birden oynamadı — ikiniz de yanıldınız, tur puansız'
            : '$ad iki kulüpte birden oynamadı! Bu tur kilitlendin';
        aramaCtrl.clear();
        adaylar = [];
      });
      _adimSonrasi();
      return;
    }
    // DOĞRU: sunucu hakemine koş — ilk kayıt turu alır
    setState(() {
      _hakemde = true;
      uyariKotu = false;
      uyari = '$ad doğru — hakem onayı bekleniyor…';
    });
    try {
      final r = await OnlineServis()
          .bayrakKap(widget.online!.bilgi.macId, turNo, bosMu: false);
      if (!mounted || engine.bitti || engine.tur != turNo) {
        _hakemde = false;
        return;
      }
      setState(() {
        _hakemde = false;
        if (r.sahip == widget.online!.bilgi.seatUid(benimSeat)) {
          // hakem beni onayladı: turu ben aldım — rakibe bildir
          widget.online!.gonder(
              {'tip': 'tursonuc', 'tur': turNo, 'kazanan': benimSeat, 'idx': idx});
          _turSonucIsle(benimSeat, idx);
        } else if (r.sahip != null) {
          // rakip benden önce yazmış
          final seat = r.sahip == widget.online!.bilgi.p1Uid ? 0 : 1;
          _turSonucIsle(seat, null);
          uyari = 'Doğruydu ama rakip SENDEN ÖNCE yazdı — tur onun!';
          uyariKotu = true;
        }
        aramaCtrl.clear();
        adaylar = [];
      });
      _adimSonrasi();
    } catch (e, s) {
      hataBildir('ortak.kap', e, s);
      if (mounted) {
        setState(() {
          _hakemde = false;
          uyariKotu = true;
          uyari = 'Bağlantı sorunu — tekrar dene';
        });
      }
    }
  }

  /// HOT-SEAT (eski kural): doğru = söz rakibe; yanlış/süre = tur rakibin.
  void _hotSeatSec(int idx, String ad) {
    final secen = engine.aktor;
    final oncekiKapali = engine.turKazanani.length;
    final dogru = engine.sec(idx);
    if (dogru == null) return;
    setState(() {
      final turKapandi = engine.turKazanani.length > oncekiKapali;
      if (!dogru) {
        uyariKotu = true;
        uyari =
            '$ad iki kulüpte birden oynamadı! Turu ${adlar[1 - secen]} aldı';
      } else if (turKapandi) {
        uyariKotu = false;
        uyari = '$ad doğru — ortaklar tükendi, turu ${adlar[secen]} aldı!';
      } else {
        uyariKotu = false;
        uyari = '$ad doğru! Söz ${adlar[engine.aktor]}\'de';
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
    if (!engine.bitti) _sayacBaslat(); // hot-seat: her hamlede taze süre
  }

  void _sonucGoster() {
    if (!mounted) return;
    _sonucAcik = true;
    final k = engine.kazanan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: GolrivaColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: GolrivaColors.edge)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                      k == null
                          ? 'BERABERE'
                          : '${adlar[k].toUpperCase()} KAZANDI',
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: GolrivaColors.goldHi,
                          letterSpacing: 1.5)),
                ),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _skorKutu(0, GolrivaColors.p1),
                      _skorKutu(1, GolrivaColors.p2),
                    ]),
                const SizedBox(height: 8),
                Text(
                    k == null
                        ? 'Turlar eşit — rövanş şart.'
                        : '${engine.skor[k]}-${engine.skor[1 - k]} ile.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        color: GolrivaColors.dim, fontSize: 13)),
                const SizedBox(height: 16),
                if (widget.online != null)
                  OnlineSonucButonlari(kanal: widget.online!, kazananSeat: k)
                else
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: GolrivaColors.gold,
                            foregroundColor: const Color(0xFF231A04),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            engine = OrtakKulupEngine(widget.repo);
                            uyari = null;
                            _sayacTuru = 0;
                          });
                          _sayacBaslat();
                        },
                        child: Text('YENİ MAÇ',
                            style: GoogleFonts.bigShouldersDisplay(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                fontSize: 17)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: GolrivaColors.ink,
                            side:
                                const BorderSide(color: GolrivaColors.edge2),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: Text('LOBİ',
                            style: GoogleFonts.bigShouldersDisplay(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                fontSize: 17)),
                      ),
                    ),
                  ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skorKutu(int s, Color renk) => Column(children: [
        Text(adlar[s].toUpperCase(),
            style: GoogleFonts.figtree(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1)),
        Text('${engine.skor[s]}',
            style: GoogleFonts.spaceGrotesk(
                color: GolrivaColors.goldHi,
                fontWeight: FontWeight.w700,
                fontSize: 26)),
        Text('tur',
            style: GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 10)),
      ]);

  @override
  void dispose() {
    sayac?.cancel();
    _hukmenTimer?.cancel();
    widget.online?.kapat();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kilitliyim =
        yaris && !engine.bitti && engine.kilitli[widget.online!.bilgi.benimSiram];
    return PopScope(
      canPop: widget.online == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.online != null) {
          cekilAkisi(context, widget.online!, onCekildi: () {
            sayac?.cancel();
            _hukmenTimer?.cancel();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Column(children: [
            Text('ORTAK KULÜP AVI',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(
                engine.bitti
                    ? 'BİTTİ'
                    : 'TUR ${engine.tur + 1}/$ortakTurSayisi · SKOR ${engine.skor[0]}-${engine.skor[1]}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: GolrivaColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
          ]),
          centerTitle: true,
          actions: [
            if (widget.online != null)
              IconButton(
                  tooltip: 'Maçtan çekil',
                  icon: const Icon(Icons.flag_outlined,
                      color: GolrivaColors.dim, size: 20),
                  onPressed: () => cekilAkisi(context, widget.online!,
                      onCekildi: () {
                        sayac?.cancel();
                        _hukmenTimer?.cancel();
                      })),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Row(children: [
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti &&
                            (yaris
                                ? !engine.kilitli[0]
                                : engine.aktor == 0),
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p1,
                        child: _ustKutu(0, GolrivaColors.p1))),
                const SizedBox(width: 10),
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti &&
                            (yaris
                                ? !engine.kilitli[1]
                                : engine.aktor == 1),
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p2,
                        child: _ustKutu(1, GolrivaColors.p2))),
              ]),
              const SizedBox(height: 10),
              if (!engine.bitti) ...[
                // ── KULÜP ÇİFTİ KARTI: büyük adlar üstte, açıklama altta ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22D4AF37), GolrivaColors.card]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GolrivaColors.edge),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _kulupKolonu(engine.kulupA)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        child: goldYazi('+', boyut: 24),
                      ),
                      Expanded(child: _kulupKolonu(engine.kulupB)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                        yaris
                            ? 'İKİSİNDE DE OYNAMIŞ FUTBOLCUYU İLK YAZAN TURU ALIR — YANLIŞ YAZAN TUR BOYU KİLİTLENİR'
                            : 'İKİ KULÜPTE DE OYNAMIŞ BİR FUTBOLCU YAZ — YANLIŞ YAZAN TURU KAYBEDER',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: GolrivaColors.dim,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: kalanSn / turSn,
                    minHeight: 5,
                    backgroundColor: GolrivaColors.card2,
                    color:
                        kalanSn <= 5 ? GolrivaColors.bad : GolrivaColors.gold,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('$kalanSn sn',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: GolrivaColors.goldHi,
                          fontWeight: FontWeight.w700)),
                ),
              ],
              if (uyari != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(uyari!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: uyariKotu
                              ? GolrivaColors.bad
                              : GolrivaColors.goldHi,
                          letterSpacing: .5)),
                ),
              ],
              if (!engine.bitti) ...[
                const SizedBox(height: 8),
                TextField(
                  // KLAVYE DUZELTMESI: sabit key
                  key: const ValueKey('arama'),
                  controller: aramaCtrl,
                  enabled: yazabilirim,
                  onChanged: (v) =>
                      setState(() => adaylar = engine.adaylar(v)),
                  decoration: InputDecoration(
                      hintText: kilitliyim
                          ? 'Bu tur kilitlisin — rakip arıyor…'
                          : _hakemde
                              ? 'Hakem kararı bekleniyor…'
                              : yaris
                                  ? 'İlk sen yaz! (en az 3 harf)'
                                  : engine.aktor == 0
                                      ? '${adlar[0]} yazıyor… (en az 3 harf)'
                                      : '${adlar[1]} yazıyor… (en az 3 harf)',
                      prefixIcon: const Icon(Icons.search,
                          color: GolrivaColors.gold, size: 20)),
                ),
                if (adaylar.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GolrivaColors.edge2)),
                    child: Material(
                      color: GolrivaColors.bg2,
                      child: Column(children: [
                        for (var i = 0; i < adaylar.length; i++) ...[
                          if (i > 0)
                            const Divider(
                                height: 1, color: GolrivaColors.edge2),
                          _adayRow(adaylar[i]),
                        ],
                      ]),
                    ),
                  ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                      yaris
                          ? 'Dikkat: yanlış isim seni bu tur kilitler!'
                          : 'Dikkat: yanlış isim turu anında kaybettirir!',
                      style: GoogleFonts.figtree(
                          fontSize: 10, color: GolrivaColors.dim2)),
                ),
              ],
              // tur geçmişi
              if (engine.turKazanani.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: kartDekor(r: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        etiket('TUR GEÇMİŞİ'),
                        const SizedBox(height: 6),
                        for (var i = 0;
                            i < engine.turKazanani.length;
                            i++)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 1.5),
                            child: Row(children: [
                              Text('${i + 1}. ',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      color: GolrivaColors.dim)),
                              Expanded(
                                child: Text(
                                    engine.turBulunan[i] == null
                                        ? (engine.turKazanani[i] == null
                                            ? 'bulunamadı'
                                            : 'hükmen/yanlış')
                                        : widget
                                            .repo
                                            .oyuncular[
                                                engine.turBulunan[i]!]
                                            .ad,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.figtree(
                                        fontSize: 11.5,
                                        color: GolrivaColors.ink)),
                              ),
                              Text(
                                  engine.turKazanani[i] == null
                                      ? 'puansız'
                                      : adlar[engine.turKazanani[i]!],
                                  style: GoogleFonts.figtree(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: engine.turKazanani[i] == null
                                          ? GolrivaColors.dim2
                                          : (engine.turKazanani[i] == 0
                                              ? GolrivaColors.p1
                                              : GolrivaColors.p2))),
                            ]),
                          ),
                      ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kulupKolonu(Kulup k) => Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(k.ad.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5)),
        ),
        Text(k.lig,
            style:
                GoogleFonts.figtree(fontSize: 9.5, color: GolrivaColors.dim)),
      ]);

  Widget _ustKutu(int s, Color renk) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: GolrivaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GolrivaColors.edge2),
        ),
        child: Column(children: [
          Text(adlar[s].toUpperCase(),
              style: GoogleFonts.figtree(
                  color: renk,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 1)),
          Text('${engine.skor[s]}',
              style: GoogleFonts.spaceGrotesk(
                  color: GolrivaColors.goldHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 22)),
          Text(
              !engine.bitti && yaris && engine.kilitli[s]
                  ? 'KİLİTLİ'
                  : 'tur',
              style: GoogleFonts.figtree(
                  color: !engine.bitti && yaris && engine.kilitli[s]
                      ? GolrivaColors.bad
                      : GolrivaColors.dim,
                  fontSize: 9)),
        ]),
      );

  Widget _adayRow(OrtakAday a) {
    final o = widget.repo.oyuncular[a.idx];
    final aktif = a.neden == null;
    return InkWell(
      onTap: aktif ? () => _sec(a) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Expanded(
            child: Text(o.ad,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: aktif ? GolrivaColors.ink : GolrivaColors.dim2)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
                // kulüp bilgisi META'DA YOK — bilgi riski oyuncuda!
                a.neden ?? '${o.poz} · ${o.ulke}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 10.5,
                    fontWeight: aktif ? FontWeight.w500 : FontWeight.w800,
                    color: aktif ? GolrivaColors.dim : GolrivaColors.bad)),
          ),
        ]),
      ),
    );
  }
}
