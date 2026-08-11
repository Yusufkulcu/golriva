import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/players_repository.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// ORTAK KULÜP AVI ekranı (Faz 2.18) — iki kulüpte de oynamış futbolcu
/// bulma düellosu. Doğru isim sözü rakibe devreder; yanlış isim ya da
/// süre dolumu TURU RAKİBE verir. Hot-seat + çevrimiçi.
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
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = turSn;
  static const turSn = 20;
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
    if (tip != 'sec' && tip != 'sure') return;
    setState(() {
      if (tip == 'sec') {
        _secIsle((h['idx'] as num).toInt());
      } else {
        _sureIsle();
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
  }

  /// Seçimi işler — iki istemcide de aynı metinler.
  void _secIsle(int idx) {
    final secen = engine.aktor;
    final oncekiKapali = engine.turKazanani.length;
    final dogru = engine.sec(idx);
    if (dogru == null) return;
    final ad = widget.repo.oyuncular[idx].ad;
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
  }

  void _sureIsle() {
    final aktor = engine.aktor;
    engine.sureDoldu();
    uyariKotu = true;
    uyari =
        '${adlar[aktor]} süreyi doldurdu — turu ${adlar[1 - aktor]} aldı';
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
          _sureIsle();
          aramaCtrl.clear();
          adaylar = [];
        });
        _adimSonrasi();
      }
    });
  }

  void _sec(OrtakAday a) {
    if (a.neden != null || !siraBende || engine.bitti) return;
    widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
    setState(() {
      _secIsle(a.idx);
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
                        'İKİ KULÜPTE DE OYNAMIŞ BİR FUTBOLCU YAZ — YANLIŞ YAZAN TURU KAYBEDER',
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
                  controller: aramaCtrl,
                  enabled: siraBende,
                  onChanged: (v) =>
                      setState(() => adaylar = engine.adaylar(v)),
                  decoration: InputDecoration(
                      hintText: siraBende
                          ? 'Futbolcu adı yaz… (en az 3 harf)'
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
                  child: Text('Dikkat: yanlış isim turu anında kaybettirir!',
                      style: GoogleFonts.figtree(
                          fontSize: 10, color: GolrivaColors.dim2)),
                ),
                // bu turda söylenenler
                if (engine.soylenen.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: kartDekor(r: 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          etiket('BU TURDA SÖYLENENLER'),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final i in engine.soylenen)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: GolrivaColors.bg2,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: GolrivaColors.edge2),
                                  ),
                                  child: Text(
                                      widget.repo.oyuncular[i].ad,
                                      style: GoogleFonts.figtree(
                                          fontSize: 11,
                                          color: GolrivaColors.ink)),
                                ),
                            ],
                          ),
                        ]),
                  ),
                ],
              ],
              // tur geçmişi
              if (engine.turKazanani.isNotEmpty) ...[
                const SizedBox(height: 12),
                Center(
                  child: Wrap(
                    spacing: 5,
                    children: [
                      for (final kz in engine.turKazanani)
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kz == 0
                                ? GolrivaColors.p1
                                : GolrivaColors.p2,
                          ),
                        ),
                    ],
                  ),
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
          Text('tur',
              style:
                  GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 9)),
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
