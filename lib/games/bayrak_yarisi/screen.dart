import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/players_repository.dart';
import '../../theme/golriva_theme.dart';
import 'engine.dart';

/// BAYRAK YARISI ekrani — refleks yarisi (hot-seat prototip).
/// Iki KAP butonu ayni ekranda; online surumde buzz farkli cihazlardan gelecek.
/// RESPONSIVE KURAL: kok yerlesim ListView.
class BayrakYarisiScreen extends StatefulWidget {
  final PlayersRepository repo;
  const BayrakYarisiScreen({super.key, required this.repo});

  @override
  State<BayrakYarisiScreen> createState() => _BayrakYarisiScreenState();
}

class _BayrakYarisiScreenState extends State<BayrakYarisiScreen> {
  late BayrakYarisiEngine engine;
  final adlar = ['Sen', 'Rakip'];
  final aramaCtrl = TextEditingController();
  List<BayrakAday> adaylar = [];
  String? turMesaji;
  Timer? sayac;
  Timer? gecisTimer;
  int kalanSn = bayrakRaceSn;
  int sureLimit = bayrakRaceSn;

  @override
  void initState() {
    super.initState();
    engine = BayrakYarisiEngine(widget.repo);
    _raceBaslat();
  }

  void _sayacKur(int sn, void Function() bitince) {
    sayac?.cancel();
    sureLimit = sn;
    kalanSn = sn;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        bitince();
      }
    });
  }

  void _raceBaslat() {
    turMesaji = null;
    _sayacKur(bayrakRaceSn, () {
      setState(() {
        engine.raceSuresiDoldu();
        turMesaji = 'Kimse cesaret edemedi';
      });
      _turSonuGecis();
    });
  }

  void _kap(int s) {
    if (!engine.kap(s)) return;
    setState(() {
      aramaCtrl.clear();
      adaylar = [];
    });
    _cevapSayaci();
  }

  void _cevapSayaci() {
    _sayacKur(bayrakCevapSn, () => _hakDus('süre doldu'));
  }

  void _hakDus(String neden) {
    final oncekiClaimer = engine.claimer;
    setState(() {
      aramaCtrl.clear();
      adaylar = [];
      if (engine.hakDus()) {
        turMesaji =
            '${adlar[oncekiClaimer]} — $neden! Hak ${adlar[engine.claimer]}\'de';
        _cevapSayaci();
      } else {
        turMesaji = 'İkisi de bilemedi';
        _turSonuGecis();
      }
    });
  }

  void _sec(BayrakAday a) {
    if (a.neden != null) return;
    final kazananS = engine.claimer;
    final o = widget.repo.oyuncular[a.idx];
    if (engine.cevapVer(a.idx)) {
      sayac?.cancel();
      setState(() {
        turMesaji =
            'DOĞRU! ${o.ad} — turu ${adlar[kazananS]} aldı';
        aramaCtrl.clear();
        adaylar = [];
      });
      _turSonuGecis();
    } else {
      // KURAL (kullanici, 30 Tem): yanlis oyuncu = hak rakibe gecer
      _hakDus('yanlış oyuncu seçti');
    }
  }

  void _turSonuGecis() {
    sayac?.cancel();
    gecisTimer?.cancel();
    gecisTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() {
        engine.sonrakiTur();
        if (!engine.bitti) _raceBaslat();
      });
      if (engine.bitti) _sonucGoster();
    });
  }

  void _sonucGoster() {
    if (!mounted) return;
    final k = engine.kazanan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
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
                    k == null ? 'BERABERE' : '${adlar[k].toUpperCase()} KAZANDI',
                    style: GoogleFonts.bigShouldersDisplay(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: GolrivaColors.goldHi,
                        letterSpacing: 1.5)),
              ),
              const SizedBox(height: 10),
              Text('${engine.skor[0]} - ${engine.skor[1]}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.goldHi)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: GolrivaColors.gold,
                        foregroundColor: const Color(0xFF231A04),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        engine = BayrakYarisiEngine(widget.repo);
                        turMesaji = null;
                      });
                      _raceBaslat();
                    },
                    child: Text('YENİ YARIŞ',
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
                        side: const BorderSide(color: GolrivaColors.edge2),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
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
    );
  }

  @override
  void dispose() {
    sayac?.cancel();
    gecisTimer?.cancel();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final race = engine.mod == BayrakMod.race;
    final answer = engine.mod == BayrakMod.answer;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text('BAYRAK YARIŞI',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text(
              engine.bitti
                  ? 'BİTTİ'
                  : 'TUR ${engine.tur + 1}/$bayrakTurSayisi · İLK KAPAN YAZAR',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: GolrivaColors.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ]),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            // skor + tur gecmisi
            Row(children: [
              Expanded(child: _skorKutu(0, GolrivaColors.p1)),
              const SizedBox(width: 10),
              Expanded(child: _skorKutu(1, GolrivaColors.p2)),
            ]),
            const SizedBox(height: 10),
            if (!engine.bitti) ...[
              // gorev karti: ULKE + KULUP
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
                  Text('BU ÜLKEDEN, BU KULÜPTE OYNAMIŞ BİRİNİ YAZ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: GolrivaColors.dim,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(ulkeTr(engine.cift.ulke).toUpperCase(),
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: GolrivaColors.goldHi,
                            letterSpacing: 1)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(engine.kulup.ad.toUpperCase(),
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                  ),
                  Text(engine.kulup.lig,
                      style: GoogleFonts.figtree(
                          fontSize: 10, color: GolrivaColors.dim)),
                ]),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: kalanSn / sureLimit,
                  minHeight: 5,
                  backgroundColor: GolrivaColors.card2,
                  color: kalanSn <= 3 ? GolrivaColors.bad : GolrivaColors.gold,
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
              if (turMesaji != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(turMesaji!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: GolrivaColors.goldHi,
                          letterSpacing: .5)),
                ),
                if (engine.mod == BayrakMod.done &&
                    engine.gecmis.isNotEmpty &&
                    engine.gecmis.last < 0)
                  Center(
                    child: Text(
                        'Geçerli cevaplardan bazıları: ${engine.ornekler().join(", ")}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 11, color: GolrivaColors.dim)),
                  ),
              ],
              const SizedBox(height: 10),
              // KAP butonlari (race) ya da cevap kutusu (answer)
              if (race)
                Row(children: [
                  Expanded(child: _kapButonu(0, GolrivaColors.p1)),
                  const SizedBox(width: 10),
                  Expanded(child: _kapButonu(1, GolrivaColors.p2)),
                ]),
              if (answer) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: (engine.claimer == 0
                              ? GolrivaColors.p1
                              : GolrivaColors.p2)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: (engine.claimer == 0
                                  ? GolrivaColors.p1
                                  : GolrivaColors.p2)
                              .withValues(alpha: .4)),
                    ),
                    child: Text(
                      '${adlar[engine.claimer]} ${adlar[engine.claimer] == "Sen" ? "yazıyorsun" : "yazıyor"} — $bayrakCevapSn saniye!',
                      style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: engine.claimer == 0
                              ? GolrivaColors.p1
                              : GolrivaColors.p2),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('Dikkat: yanlış oyuncu seçersen hak rakibe geçer!',
                      style: GoogleFonts.figtree(
                          fontSize: 10.5, color: GolrivaColors.dim)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: aramaCtrl,
                  onChanged: (v) =>
                      setState(() => adaylar = engine.adaylar(v)),
                  decoration: const InputDecoration(
                      hintText: 'Futbolcu adı yaz… (en az 3 harf)',
                      prefixIcon: Icon(Icons.search,
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
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: GolrivaColors.dim,
                        side: const BorderSide(color: GolrivaColors.edge2)),
                    onPressed: () => _hakDus('pas geçti'),
                    child: Text('PAS',
                        style: GoogleFonts.bigShouldersDisplay(
                            fontWeight: FontWeight.w800, letterSpacing: 2)),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            // tur gecmisi noktalari
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var t = 0; t < bayrakTurSayisi; t++)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t < engine.gecmis.length
                          ? (engine.gecmis[t] == 0
                              ? GolrivaColors.p1
                              : engine.gecmis[t] == 1
                                  ? GolrivaColors.p2
                                  : GolrivaColors.dim2)
                          : GolrivaColors.card2,
                      border: Border.all(color: GolrivaColors.edge2),
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skorKutu(int s, Color renk) => Container(
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

  Widget _kapButonu(int s, Color renk) {
    final kullanildi = engine.denenen.contains(s);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor:
            kullanildi ? GolrivaColors.card2 : renk.withValues(alpha: .16),
        foregroundColor: kullanildi ? GolrivaColors.dim2 : renk,
        padding: const EdgeInsets.symmetric(vertical: 22),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
                color: kullanildi
                    ? GolrivaColors.edge2
                    : renk.withValues(alpha: .5))),
      ),
      onPressed: kullanildi ? null : () => _kap(s),
      child: Text('${adlar[s].toUpperCase()} KAP!',
          style: GoogleFonts.bigShouldersDisplay(
              fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 1.5)),
    );
  }

  Widget _adayRow(BayrakAday a) {
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
                // ULKE GIZLI (kullanici kurali) — sadece dogum yili
                a.neden ?? (o.dogumYili > 0 ? '${o.dogumYili}' : ''),
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
