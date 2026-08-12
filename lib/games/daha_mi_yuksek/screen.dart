import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repos.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// DAHA MI YÜKSEK? ekranı (Faz 2.18) — karşılaştırma düellosu.
/// Soldakinin değeri açık, sağdakininki gizli: DAHA YÜKSEK mi DÜŞÜK mü?
/// 10 tur, 5'er karar. Hot-seat + çevrimiçi.
/// RESPONSIVE KURAL: kök yerleşim ListView.
class DahaMiYuksekScreen extends StatefulWidget {
  final GolrivaRepos repos;
  final OnlineMacKanali? online; // null = hot-seat
  const DahaMiYuksekScreen({super.key, required this.repos, this.online});

  @override
  State<DahaMiYuksekScreen> createState() => _DahaMiYuksekScreenState();
}

class _DahaMiYuksekScreenState extends State<DahaMiYuksekScreen> {
  late DahaMiYuksekEngine engine;
  late final List<String> adlar;
  String? uyari;
  bool? sonDogru; // uyarı rengi için
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = turSn;
  static const turSn = 15;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  bool get siraBende =>
      widget.online == null || engine.aktor == widget.online!.bilgi.benimSiram;

  @override
  void initState() {
    super.initState();
    final o = widget.online;
    adlar = o == null
        ? ['Sen', 'Rakip']
        : (o.bilgi.benimSiram == 0
            ? ['Sen', o.bilgi.rakipAdi]
            : [o.bilgi.rakipAdi, 'Sen']);
    engine = DahaMiYuksekEngine(widget.repos,
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
    if (tip != 'cevap' && tip != 'sure') return;
    setState(() {
      if (tip == 'cevap') {
        _cevapIsle(yuksek: h['yuksek'] == true, benim: false);
      } else {
        _sureIsle(benim: false);
      }
    });
    _adimSonrasi();
  }

  /// Cevabı işler, açılan değeri iki istemcide aynı metinle gösterir.
  void _cevapIsle({required bool yuksek, required bool benim}) {
    final s = engine.soru;
    final karar = engine.aktor;
    final dogru = engine.cevap(yuksek: yuksek);
    sonDogru = dogru;
    uyari =
        '${s.sagAd}: ${dahaFmt(s.sagDeger)} ${s.birim} — ${adlar[karar]} ${dogru ? "DOĞRU (+1)" : "YANLIŞ"}';
  }

  void _sureIsle({required bool benim}) {
    final s = engine.soru;
    final karar = engine.aktor;
    engine.sureDoldu();
    sonDogru = false;
    uyari =
        '${s.sagAd}: ${dahaFmt(s.sagDeger)} ${s.birim} — ${adlar[karar]} süreyi doldurdu';
  }

  void _adimSonrasi() {
    if (engine.bitti) {
      sayac?.cancel();
      _sonucGoster();
    } else {
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
        if (widget.online != null && !siraBende) {
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && !siraBende) _macKapandi();
          });
          return;
        }
        widget.online?.gonder({'tip': 'sure'});
        setState(() => _sureIsle(benim: true));
        _adimSonrasi();
      }
    });
  }

  void _cevapla(bool yuksek) {
    if (!siraBende || engine.bitti) return;
    widget.online?.gonder({'tip': 'cevap', 'yuksek': yuksek});
    setState(() => _cevapIsle(yuksek: yuksek, benim: true));
    _adimSonrasi();
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
                        ? 'Skorlar eşit — rövanş şart.'
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
                            engine = DahaMiYuksekEngine(widget.repos);
                            uyari = null;
                            sonDogru = null;
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
        Text('doğru',
            style: GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 10)),
      ]);

  @override
  void dispose() {
    sayac?.cancel();
    _hukmenTimer?.cancel();
    widget.online?.kapat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = engine.bitti ? null : engine.soru;
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
            Text('DAHA MI YÜKSEK?',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(
                engine.bitti
                    ? 'BİTTİ'
                    : 'TUR ${engine.tur + 1}/$dahaTurSayisi · SKOR ${engine.skor[0]}-${engine.skor[1]}',
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
                        aktif: !engine.bitti && engine.aktor == 0,
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p1,
                        child: _ustKutu(0, GolrivaColors.p1))),
                const SizedBox(width: 10),
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti && engine.aktor == 1,
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p2,
                        child: _ustKutu(1, GolrivaColors.p2))),
              ]),
              if (widget.online != null && !engine.bitti) ...[
                const SizedBox(height: 10),
                SiraSeridi(
                    siraBende: siraBende,
                    rakipAdi: widget.online!.bilgi.rakipAdi),
              ],
              const SizedBox(height: 10),
              if (s != null) ...[
                // ── METRİK KARTI: büyük ad üstte, açıklama altta ──
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(s.metrikAd,
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'SAĞDAKİ SOLDAKİNDEN DAHA MI YÜKSEK, DAHA MI DÜŞÜK?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 9,
                            letterSpacing: 2.5,
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
                        kalanSn <= 4 ? GolrivaColors.bad : GolrivaColors.gold,
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
                const SizedBox(height: 10),
                // ── KARŞILAŞTIRMA KARTLARI ──
                // DİKKAT: ListView içinde stretch KULLANILMAZ — sonsuz
                // yükseklik dayatır, render patlar (siyah ekran hatası).
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: _oyuncuKart(
                          ad: s.solAd,
                          deger: '${dahaFmt(s.solDeger)} ${s.birim}',
                          acik: true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(child: goldYazi('VS', boyut: 22)),
                  ),
                  Expanded(
                      child: _oyuncuKart(
                          ad: s.sagAd, deger: '?', acik: false)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: siraBende
                              ? GolrivaColors.ok.withValues(alpha: .85)
                              : GolrivaColors.card2,
                          foregroundColor: siraBende
                              ? Colors.white
                              : GolrivaColors.dim2,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13)),
                      onPressed:
                          siraBende ? () => _cevapla(true) : null,
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      label: Text('DAHA YÜKSEK',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: siraBende
                              ? GolrivaColors.bad.withValues(alpha: .85)
                              : GolrivaColors.card2,
                          foregroundColor: siraBende
                              ? Colors.white
                              : GolrivaColors.dim2,
                          padding:
                              const EdgeInsets.symmetric(vertical: 13)),
                      onPressed:
                          siraBende ? () => _cevapla(false) : null,
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: Text('DAHA DÜŞÜK',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 15)),
                    ),
                  ),
                ]),
              ],
              if (uyari != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(uyari!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: sonDogru == true
                              ? GolrivaColors.ok
                              : GolrivaColors.bad,
                          letterSpacing: .5)),
                ),
              ],
              const SizedBox(height: 12),
              // ── TUR GEÇMİŞİ NOKTALARI ──
              if (engine.dogruMu.isNotEmpty)
                Center(
                  child: Wrap(
                    spacing: 5,
                    children: [
                      for (var i = 0; i < engine.dogruMu.length; i++)
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: engine.dogruMu[i] == true
                                ? GolrivaColors.ok
                                : engine.dogruMu[i] == false
                                    ? GolrivaColors.bad
                                    : GolrivaColors.card2,
                            border: Border.all(
                                color: i % 2 == 0
                                    ? GolrivaColors.p1
                                    : GolrivaColors.p2,
                                width: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
          Text('doğru',
              style:
                  GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 9)),
        ]),
      );

  Widget _oyuncuKart(
          {required String ad, required String deger, required bool acik}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: GolrivaColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: acik ? GolrivaColors.edge : GolrivaColors.goldDeep),
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(ad,
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: GolrivaColors.ink)),
          ),
          const SizedBox(height: 8),
          Text(deger,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: acik ? 17 : 26,
                  fontWeight: FontWeight.w700,
                  color: acik ? GolrivaColors.goldHi : GolrivaColors.gold)),
        ]),
      );
}
