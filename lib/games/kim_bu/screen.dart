import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/kor_av_repository.dart';
import '../../data/players_repository.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// KİM BU? ekranı (Faz 2.18) — ipucu açık artırması.
/// Sıranda ya İPUCU AÇ (söz rakibe geçer) ya da TAHMİN ET. Erken bilen
/// çok puan alır; yanlış tahmin turu kilitler. Hot-seat + çevrimiçi.
/// RESPONSIVE KURAL: kök yerleşim ListView.
class KimBuScreen extends StatefulWidget {
  final KorAvRepository repo;
  final PlayersRepository? kulupRepo; // OYNADIĞI KULÜP ipucu kaynağı
  final OnlineMacKanali? online; // null = hot-seat
  const KimBuScreen(
      {super.key, required this.repo, this.kulupRepo, this.online});

  @override
  State<KimBuScreen> createState() => _KimBuScreenState();
}

class _KimBuScreenState extends State<KimBuScreen> {
  late KimBuEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<KimBuAday> adaylar = [];
  String? uyari;
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = turSn;
  static const turSn = 20;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  bool get siraBende =>
      widget.online == null || engine.aktor == widget.online!.bilgi.benimSiram;

  String? get _siraNotu {
    if (widget.online == null || engine.bitti) return null;
    final ben = widget.online!.bilgi.benimSiram;
    if (engine.kilitli[ben]) {
      return 'Yanlış tahmin — bu tur kilitlisin, rakip tek başına devam ediyor.';
    }
    if (engine.kilitli[1 - ben]) {
      return 'Rakip kilitlendi — art arda kararlar sende.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final o = widget.online;
    adlar = o == null
        ? ['Sen', 'Rakip']
        : (o.bilgi.benimSiram == 0
            ? ['Sen', o.bilgi.rakipAdi]
            : [o.bilgi.rakipAdi, 'Sen']);
    engine = KimBuEngine(widget.repo,
        kulupRepo: widget.kulupRepo,
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
    if (tip != 'ac' && tip != 'tahmin' && tip != 'sure') return;
    setState(() {
      if (tip == 'ac') {
        engine.ipucuAc();
        uyari = 'Rakip yeni ipucu açtı';
      } else if (tip == 'tahmin') {
        _tahminIsle((h['idx'] as num).toInt(), benim: false);
      } else {
        _sureIsle(benim: false);
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
  }

  /// Tahmin sonucunu İKİ istemcide de aynı metinlerle işler.
  void _tahminIsle(int idx, {required bool benim}) {
    final oncekiGizem = engine.gizem.ad;
    final oncekiKapali = engine.turKazanani.length;
    final puan = engine.turPuani;
    final tahminci = engine.aktor;
    final dogru = engine.tahmin(idx);
    if (dogru == null) return;
    final ad = widget.repo.oyuncular[idx].ad;
    final turKapandi = engine.turKazanani.length > oncekiKapali;
    if (dogru) {
      uyari = '$oncekiGizem! ${adlar[tahminci]} +$puan puan';
    } else if (turKapandi) {
      // iki taraf da yanıldı — gizemi açıkla
      uyari = 'Yanlış ($ad) — gizem $oncekiGizem\'di, tur puansız kapandı';
    } else {
      uyari = benim
          ? 'Yanlış ($ad) — bu tur kilitlendin'
          : 'Rakip yanıldı ($ad) — söz sende';
    }
  }

  void _sureIsle({required bool benim}) {
    if (engine.ipucuKaldi) {
      engine.sureDoldu();
      uyari = 'Süre doldu — ipucu otomatik açıldı';
      return;
    }
    final oncekiGizem = engine.gizem.ad;
    final oncekiTur = engine.tur;
    engine.sureDoldu();
    final turKapandi = engine.bitti || engine.tur != oncekiTur;
    uyari = turKapandi
        ? 'Gizem $oncekiGizem\'di — tur puansız kapandı'
        : (benim ? 'Süre doldu — kilitlendin' : 'Rakibin süresi doldu');
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
        setState(() {
          _sureIsle(benim: true);
          aramaCtrl.clear();
          adaylar = [];
        });
        _adimSonrasi();
      }
    });
  }

  void _ipucuAc() {
    if (!siraBende || !engine.ipucuKaldi) return;
    setState(() {
      if (engine.ipucuAc()) {
        widget.online?.gonder({'tip': 'ac'});
        // rakip kilitliyse söz bende kalır — metin yanıltmasın
        final benimSeat = widget.online == null
            ? engine.aktor
            : widget.online!.bilgi.benimSiram;
        uyari = engine.aktor == benimSeat
            ? 'Yeni ipucu açıldı — rakip kilitli, söz sende'
            : 'Yeni ipucu açıldı — söz rakipte';
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    _adimSonrasi();
  }

  void _tahmin(KimBuAday a) {
    if (!siraBende) return;
    setState(() {
      widget.online?.gonder({'tip': 'tahmin', 'idx': a.idx});
      _tahminIsle(a.idx, benim: true);
      aramaCtrl.clear();
      adaylar = [];
    });
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
                        ? 'Puanlar eşit — rövanş şart.'
                        : '${(engine.skor[0] - engine.skor[1]).abs()} puan farkla.',
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
                            engine = KimBuEngine(widget.repo,
                                kulupRepo: widget.kulupRepo);
                            uyari = null;
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
        Text('puan',
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
    final benimSeat =
        widget.online == null ? engine.aktor : widget.online!.bilgi.benimSiram;
    final kilitliyim = !engine.bitti && engine.kilitli[benimSeat];
    final oynayabilirim = !engine.bitti && siraBende && !kilitliyim;
    final ipuclari = engine.bitti ? <(String, String)>[] : engine.acikIpuclari();
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
            Text('KİM BU?',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(
                engine.bitti
                    ? 'BİTTİ'
                    : 'TUR ${engine.tur + 1}/$kimBuTurSayisi · SKOR ${engine.skor[0]}-${engine.skor[1]}',
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
                    rakipAdi: widget.online!.bilgi.rakipAdi,
                    notu: _siraNotu),
              ],
              const SizedBox(height: 10),
              // ── İPUCU KARTI: büyük başlık üstte, açıklama altta ──
              if (!engine.bitti)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
                      child: Text('GİZEMLİ FUTBOLCU',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                        'İPUCU AÇ = SÖZ RAKİBE GEÇER · ERKEN BİLEN ÇOK KAZANIR',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 9,
                            letterSpacing: 2.5,
                            color: GolrivaColors.dim,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                        'TEK TAHMİN HAKKIN VAR — YANLIŞ BİLİRSEN BU TUR '
                        'BİR DAHA CEVAP VEREMEZSİN',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: GolrivaColors.bad,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final (ad, deger) in ipuclari)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: GolrivaColors.bg2,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: GolrivaColors.goldDeep),
                            ),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                    text: '$ad: ',
                                    style: GoogleFonts.figtree(
                                        fontSize: 10.5,
                                        color: GolrivaColors.dim,
                                        fontWeight: FontWeight.w700)),
                                TextSpan(
                                    text: deger,
                                    style: GoogleFonts.figtree(
                                        fontSize: 11.5,
                                        color: GolrivaColors.goldHi,
                                        fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                        for (var i = ipuclari.length;
                            i < engine.ipucuSayisi;
                            i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: GolrivaColors.card2,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: GolrivaColors.edge2),
                            ),
                            child: const Icon(Icons.lock_outline,
                                size: 13, color: GolrivaColors.dim2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('DOĞRU TAHMİN ŞU AN +${engine.turPuani} PUAN',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            color: GolrivaColors.goldHi,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ]),
                ),
              const SizedBox(height: 10),
              if (!engine.bitti) ...[
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
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: uyari!.startsWith('Yanlış') ||
                                  uyari!.contains('kilitlen')
                              ? GolrivaColors.bad
                              : GolrivaColors.goldHi,
                          letterSpacing: .5)),
                ),
              ],
              if (!engine.bitti) ...[
                const SizedBox(height: 8),
                if (oynayabilirim && engine.ipucuKaldi)
                  Center(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: GolrivaColors.goldHi,
                          side:
                              const BorderSide(color: GolrivaColors.goldDeep),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10)),
                      onPressed: _ipucuAc,
                      icon: const Icon(Icons.lightbulb_outline, size: 17),
                      label: Text('İPUCU AÇ',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 15)),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  // KLAVYE DUZELTMESI: sabit key — liste yapisi
                  // degisince eleman yeniden yaratilip odak/klavye dusuyordu.
                  key: const ValueKey('arama'),
                  controller: aramaCtrl,
                  enabled: oynayabilirim,
                  onChanged: (v) =>
                      setState(() => adaylar = engine.adaylar(v)),
                  decoration: InputDecoration(
                      hintText: oynayabilirim
                          ? 'Tahminini yaz… (en az 3 harf)'
                          : kilitliyim
                              ? 'Bu tur kilitlisin…'
                              : '${adlar[engine.aktor]} düşünüyor…',
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
                      'Dikkat: yanlış tahmin bu turu kilitler!',
                      style: GoogleFonts.figtree(
                          fontSize: 10, color: GolrivaColors.dim2)),
                ),
              ],
              const SizedBox(height: 12),
              // geçmiş turlar
              if (engine.turKazanani.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: kartDekor(r: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        etiket('GEÇMİŞ TURLAR'),
                        const SizedBox(height: 6),
                        for (var i = 0; i < engine.turKazanani.length; i++)
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
                                    widget
                                        .repo
                                        .oyuncular[engine.gizemler[i]].ad,
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
          Text(
              !engine.bitti && engine.kilitli[s] ? 'KİLİTLİ' : 'puan',
              style: GoogleFonts.figtree(
                  color: !engine.bitti && engine.kilitli[s]
                      ? GolrivaColors.bad
                      : GolrivaColors.dim,
                  fontSize: 9)),
        ]),
      );

  Widget _adayRow(KimBuAday a) {
    final o = widget.repo.oyuncular[a.idx];
    return InkWell(
      onTap: () => _tahmin(a),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Expanded(
            child: Text(o.ad,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: GolrivaColors.ink)),
          ),
          // META YOK: mevki/ülke gösterilse ipuçlarıyla çapraz elenirdi
          Text('TAHMİN ET',
              style: GoogleFonts.figtree(
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: GolrivaColors.goldDeep)),
        ]),
      ),
    );
  }
}
