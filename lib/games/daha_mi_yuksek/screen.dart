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

/// DAHA MI YÜKSEK? ekranı (Faz 2.18 · v2) — İKİ OYUNCU AYNI SORULARI CEVAPLAR.
/// Çevrimiçi: EŞ ZAMANLI — herkes kendi cihazında karar verir, tur iki taraf
/// da cevaplayınca açılır. Hot-seat: aynı soruyu önce O1 sonra O2 cevaplar.
/// Soldakinin değeri açık, sağdakininki gizli: DAHA YÜKSEK mi DÜŞÜK mü?
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
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = turSn;
  int _sayacTuru = 0;
  static const turSn = 15;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  /// Çevrimiçi: benim koltuk sabit. Hot-seat: sıradaki cevaplayan koltuk.
  int get benimSeat {
    final o = widget.online;
    if (o != null) return o.bilgi.benimSiram;
    return !engine.bitti && engine.cevapladi(0) ? 1 : 0;
  }

  bool get cevapladim => engine.bitti || engine.cevapladi(benimSeat);

  /// Son TAMAMLANMIŞ turun indeksi (açılış paneli) — yoksa -1.
  int get acilanTur => engine.bitti ? dahaTurSayisi - 1 : engine.tur - 1;

  @override
  void initState() {
    super.initState();
    final o = widget.online;
    adlar = o == null
        ? ['Oyuncu 1', 'Oyuncu 2']
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
    final rakipSeat = 1 - widget.online!.bilgi.benimSiram;
    final hTur = (h['tur'] as num?)?.toInt() ?? engine.tur;
    if (hTur != engine.tur) return; // eski tur — yoksay
    setState(() {
      if (tip == 'cevap') {
        engine.cevap(rakipSeat, yuksek: h['yuksek'] == true);
      } else {
        engine.sureDoldu(rakipSeat);
      }
    });
    _adimSonrasi();
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
        if (widget.online != null && cevapladim) {
          // ben cevapladım, rakip gecikti — hamlesi kendi istemcisinden
          // gelir; gelmezse hükmen ağı devreye girer
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && cevapladim) _macKapandi();
          });
          return;
        }
        setState(() {
          if (widget.online != null) {
            widget.online!.gonder({'tip': 'sure', 'tur': engine.tur});
            engine.sureDoldu(benimSeat);
          } else {
            // hot-seat: cevaplamayan herkes süreden yanar
            if (!engine.cevapladi(0)) engine.sureDoldu(0);
            if (!engine.bitti && !engine.cevapladi(1)) engine.sureDoldu(1);
          }
        });
        _adimSonrasi();
      }
    });
  }

  void _cevapla(bool yuksek) {
    if (cevapladim || engine.bitti) return;
    setState(() {
      if (widget.online != null) {
        widget.online!
            .gonder({'tip': 'cevap', 'tur': engine.tur, 'yuksek': yuksek});
      }
      engine.cevap(benimSeat, yuksek: yuksek);
    });
    _adimSonrasi();
    // hot-seat: sıradaki cevaplayan (ya da yeni tur) taze süre alır
    if (widget.online == null && !engine.bitti) _sayacBaslat();
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
                        aktif: !engine.bitti && !engine.cevapladi(0),
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p1,
                        child: _ustKutu(0, GolrivaColors.p1))),
                const SizedBox(width: 10),
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti && !engine.cevapladi(1),
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p2,
                        child: _ustKutu(1, GolrivaColors.p2))),
              ]),
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
                        widget.online != null
                            ? 'İKİNİZE DE AYNI SORU — SAĞDAKİ SOLDAKİNDEN DAHA MI YÜKSEK, DAHA MI DÜŞÜK?'
                            : 'AYNI SORUYU ÖNCE ${adlar[0].toUpperCase()} SONRA ${adlar[1].toUpperCase()} CEVAPLAR',
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
                    child: goldYazi('VS', boyut: 22),
                  ),
                  Expanded(
                      child: _oyuncuKart(
                          ad: s.sagAd, deger: '?', acik: false)),
                ]),
                const SizedBox(height: 12),
                if (!cevapladim) ...[
                  if (widget.online == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Center(
                        child: Text('CEVAPLAYAN: ${adlar[benimSeat]}',
                            style: GoogleFonts.figtree(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: benimSeat == 0
                                    ? GolrivaColors.p1
                                    : GolrivaColors.p2)),
                      ),
                    ),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                GolrivaColors.ok.withValues(alpha: .85),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13)),
                        onPressed: () => _cevapla(true),
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
                            backgroundColor:
                                GolrivaColors.bad.withValues(alpha: .85),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 13)),
                        onPressed: () => _cevapla(false),
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        label: Text('DAHA DÜŞÜK',
                            style: GoogleFonts.bigShouldersDisplay(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 15)),
                      ),
                    ),
                  ]),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: kartDekor(r: 16),
                    child: Row(children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: GolrivaColors.gold, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            widget.online != null
                                ? 'Cevabın alındı — rakip bekleniyor. Değer iki taraf da cevaplayınca açılır.'
                                : 'Kayıt alındı.',
                            style: GoogleFonts.figtree(
                                fontSize: 12, color: GolrivaColors.dim)),
                      ),
                    ]),
                  ),
                ],
              ],
              // ── SON TAMAMLANAN TURUN AÇILIŞI ──
              if (acilanTur >= 0) ...[
                const SizedBox(height: 12),
                _acilisPaneli(acilanTur),
              ],
              const SizedBox(height: 12),
              // ── TUR GEÇMİŞİ (taraf başına nokta) ──
              if (acilanTur >= 0)
                Center(
                  child: Column(children: [
                    for (final tarafS in [0, 1])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(adlar[tarafS],
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.figtree(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: tarafS == 0
                                          ? GolrivaColors.p1
                                          : GolrivaColors.p2)),
                            ),
                            for (var i = 0; i <= acilanTur; i++)
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: engine.sonuclar[i][tarafS] == 1
                                      ? GolrivaColors.ok
                                      : engine.sonuclar[i][tarafS] == 0
                                          ? GolrivaColors.bad
                                          : GolrivaColors.card2,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _acilisPaneli(int ti) {
    final s = engine.sorular[ti];
    String durumYazi(int? d) =>
        d == 1 ? 'DOĞRU' : (d == 0 ? 'YANLIŞ' : 'süre doldu');
    Color durumRenk(int? d) =>
        d == 1 ? GolrivaColors.ok : GolrivaColors.bad;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: kartDekor(r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        etiket('${s.metrikAd} — AÇILAN DEĞER'),
        const SizedBox(height: 6),
        Text(
            '${s.solAd}: ${dahaFmt(s.solDeger)} ${s.birim} — '
            '${s.sagAd}: ${dahaFmt(s.sagDeger)} ${s.birim} '
            '(${s.sagYuksek ? "DAHA YÜKSEK" : "DAHA DÜŞÜK"})',
            style: GoogleFonts.figtree(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.ink)),
        const SizedBox(height: 4),
        Row(children: [
          for (final tarafS in [0, 1]) ...[
            if (tarafS == 1) const SizedBox(width: 14),
            Text('${adlar[tarafS]}: ',
                style: GoogleFonts.figtree(
                    fontSize: 11, color: GolrivaColors.dim)),
            Text(durumYazi(engine.sonuclar[ti][tarafS]),
                style: GoogleFonts.figtree(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: durumRenk(engine.sonuclar[ti][tarafS]))),
          ],
        ]),
      ]),
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
          Text(
              engine.bitti
                  ? 'doğru'
                  : engine.cevapladi(s)
                      ? 'CEVAPLADI'
                      : 'düşünüyor…',
              style: GoogleFonts.figtree(
                  color: engine.cevapladi(s) && !engine.bitti
                      ? GolrivaColors.ok
                      : GolrivaColors.dim,
                  fontSize: 9)),
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
