import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/kupa_repository.dart';
import '../../theme/golriva_theme.dart';
import 'engine.dart';

/// KUPA DRAFTI ekrani — hot-seat draft. Kupa sayisi secimde ANINDA acilir,
/// toplam ustte birikir, YUKSEK kazanir. RESPONSIVE KURAL: kok ListView.
class KupaDraftiScreen extends StatefulWidget {
  final KupaRepository repo;
  const KupaDraftiScreen({super.key, required this.repo});

  @override
  State<KupaDraftiScreen> createState() => _KupaDraftiScreenState();
}

class _KupaDraftiScreenState extends State<KupaDraftiScreen> {
  late KupaDraftEngine engine;
  final adlar = ['Sen', 'Rakip'];
  final aramaCtrl = TextEditingController();
  List<KupaAday> adaylar = [];
  String? sonAcilan;
  Timer? sayac;
  int kalanSn = 20;
  static const turSn = 20;

  @override
  void initState() {
    super.initState();
    engine = KupaDraftEngine(widget.repo);
    _sayacBaslat();
  }

  void _sayacBaslat() {
    sayac?.cancel();
    kalanSn = turSn;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        setState(() {
          engine.sureDoldu();
          sonAcilan = 'Süre doldu — etap boş geçti';
          aramaCtrl.clear();
          adaylar = [];
        });
        _sonrakiAdim();
      }
    });
  }

  void _sonrakiAdim() {
    if (engine.bitti) {
      sayac?.cancel();
      _sonucGoster();
    } else {
      _sayacBaslat();
    }
  }

  void _sec(KupaAday a) {
    if (a.neden != null) return;
    final o = widget.repo.oyuncular[a.idx];
    setState(() {
      if (engine.sec(a.idx)) {
        sonAcilan = '${o.ad} — ${o.kupa} kupa';
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    _sonrakiAdim();
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _toplamKutu(0, GolrivaColors.p1),
                _toplamKutu(1, GolrivaColors.p2),
              ]),
              const SizedBox(height: 8),
              Text(
                  k == null
                      ? 'Kupa sayıları eşit — rövanş şart.'
                      : '${(engine.toplam(0) - engine.toplam(1)).abs()} kupa farkla.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                      color: GolrivaColors.dim, fontSize: 13)),
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
                        engine = KupaDraftEngine(widget.repo);
                        sonAcilan = null;
                      });
                      _sayacBaslat();
                    },
                    child: Text('YENİ DRAFT',
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

  Widget _toplamKutu(int s, Color renk) => Column(children: [
        Text(adlar[s].toUpperCase(),
            style: GoogleFonts.figtree(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1)),
        Text('${engine.toplam(s)}',
            style: GoogleFonts.spaceGrotesk(
                color: GolrivaColors.goldHi,
                fontWeight: FontWeight.w700,
                fontSize: 26)),
        Text('kupa',
            style: GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 10)),
      ]);

  @override
  void dispose() {
    sayac?.cancel();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secen = engine.bitti ? 0 : engine.simdiSecen;
    final acik = engine.bitti ? <String>[] : engine.acikMevkiler(secen);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text('KUPA DRAFTI',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text(engine.bitti ? 'BİTTİ' : 'TUR ${engine.tur + 1}/$kupaTurSayisi',
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
            Row(children: [
              Expanded(child: _ustToplam(0, GolrivaColors.p1)),
              const SizedBox(width: 10),
              Expanded(child: _ustToplam(1, GolrivaColors.p2)),
            ]),
            const SizedBox(height: 10),
            if (!engine.bitti)
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
                  Text('BU KULÜPTE OYNAMIŞ EN KUPALI OYUNCUYU YAZ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: GolrivaColors.dim,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(engine.kulup.ad.toUpperCase(),
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                  ),
                  Text(engine.kulup.lig,
                      style: GoogleFonts.figtree(
                          fontSize: 10, color: GolrivaColors.dim)),
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
                  color: kalanSn <= 5 ? GolrivaColors.bad : GolrivaColors.gold,
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
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: (secen == 0 ? GolrivaColors.p1 : GolrivaColors.p2)
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color:
                            (secen == 0 ? GolrivaColors.p1 : GolrivaColors.p2)
                                .withValues(alpha: .4)),
                  ),
                  child: Text(
                    '${adlar[secen]} seçiyor · Açık: ${acik.map((z) => kupaSlotAd[z]).join(" · ")}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secen == 0 ? GolrivaColors.p1 : GolrivaColors.p2),
                  ),
                ),
              ),
              if (sonAcilan != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(sonAcilan!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: GolrivaColors.goldHi,
                          letterSpacing: .5)),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: aramaCtrl,
                onChanged: (v) => setState(() => adaylar = engine.adaylar(v)),
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
                          const Divider(height: 1, color: GolrivaColors.edge2),
                        _adayRow(adaylar[i]),
                      ],
                    ]),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _kadro(0, GolrivaColors.p1)),
              const SizedBox(width: 10),
              Expanded(child: _kadro(1, GolrivaColors.p2)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _ustToplam(int s, Color renk) => Container(
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${engine.toplam(s)}',
                style: GoogleFonts.spaceGrotesk(
                    color: GolrivaColors.goldHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 22)),
          ),
          Text('kupa',
              style:
                  GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 9)),
        ]),
      );

  Widget _adayRow(KupaAday a) {
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
                // kupa sayisi META'DA YOK — tahmin konusu!
                a.neden ?? '${kupaSlotAd[o.poz]} · ${o.ulke}',
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

  Widget _kadro(int s, Color renk) {
    final bySlot = <String, List<int>>{'K': [], 'D': [], 'O': [], 'F': []};
    for (final p in engine.kadrolar[s]) {
      bySlot[p.poz]!.add(p.idx);
    }
    final sayim = {'K': 0, 'D': 0, 'O': 0, 'F': 0};
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GolrivaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GolrivaColors.edge2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(adlar[s].toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    color: renk,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1)),
          ),
          Text('${engine.kadrolar[s].length}/$kupaTurSayisi',
              style: GoogleFonts.spaceGrotesk(
                  color: GolrivaColors.dim, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        for (final z in kupaSlotOrder) _slotSatir(s, z, bySlot, sayim),
      ]),
    );
  }

  Widget _slotSatir(int s, String z, Map<String, List<int>> bySlot,
      Map<String, int> sayim) {
    final list = bySlot[z]!;
    final k = sayim[z]!;
    sayim[z] = k + 1;
    final i = k < list.length ? list[k] : -1;
    final dolu = i >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: GolrivaColors.card2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Text(z,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.gold)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(dolu ? widget.repo.oyuncular[i].ad : '—',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: dolu ? GolrivaColors.ink : GolrivaColors.dim2)),
        ),
        const SizedBox(width: 6),
        Text(dolu ? '${widget.repo.oyuncular[i].kupa}' : '',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.goldHi)),
      ]),
    );
  }
}
