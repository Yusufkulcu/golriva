import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/ikiz_repository.dart';
import '../../theme/golriva_theme.dart';
import 'engine.dart';

/// KARIYER IKIZI ekrani — 5 soruluk kariyer tahmin duellosu (hot-seat).
/// Referans kariyeri acik; her soruda hedefe EN YAKIN futbolcuyu yazan puani
/// alir. RESPONSIVE KURAL: kok yerlesim ListView.
class KariyerIkiziScreen extends StatefulWidget {
  final IkizRepository repo;
  const KariyerIkiziScreen({super.key, required this.repo});

  @override
  State<KariyerIkiziScreen> createState() => _KariyerIkiziScreenState();
}

class _KariyerIkiziScreenState extends State<KariyerIkiziScreen> {
  late KariyerIkiziEngine engine;
  final adlar = ['Sen', 'Rakip'];
  final aramaCtrl = TextEditingController();
  List<IkizAday> adaylar = [];
  String? uyari;
  Timer? sayac;
  int kalanSn = ikizTurSaniye;

  @override
  void initState() {
    super.initState();
    engine = KariyerIkiziEngine(widget.repo);
    _sayacBaslat();
  }

  void _sayacBaslat() {
    sayac?.cancel();
    kalanSn = ikizTurSaniye;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        setState(() {
          uyari = '${adlar[engine.simdiYazan]} — süre doldu, cevapsız';
          engine.sureDoldu();
          aramaCtrl.clear();
          adaylar = [];
        });
        if (!engine.soruKapandi) _sayacBaslat();
      }
    });
  }

  void _sec(IkizAday a) {
    if (a.neden != null) return;
    setState(() {
      if (engine.sec(a.idx)) {
        uyari = null;
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    if (!engine.soruKapandi) {
      _sayacBaslat();
    } else {
      sayac?.cancel();
    }
  }

  void _sonraki() {
    setState(() {
      engine.sonrakiSoru();
      uyari = null;
    });
    if (engine.bitti) {
      sayac?.cancel();
      _sonucGoster();
    } else {
      _sayacBaslat();
    }
  }

  void _sonucGoster() {
    if (!mounted) return;
    final k = engine.kazanan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        // geri tuşu bu diyaloğu KAPATAMAZ — sonuç akışı asılı kalmasın
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
                        engine = KariyerIkiziEngine(widget.repo);
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
      ),
    );
  }

  @override
  void dispose() {
    sayac?.cancel();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yazan = engine.bitti || engine.soruKapandi ? 0 : engine.simdiYazan;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text('KARİYER İKİZİ',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text(
              engine.bitti
                  ? 'BİTTİ'
                  : 'SORU ${engine.soru + 1}/$ikizSoruSayisi · ${engine.skor[0]} - ${engine.skor[1]}',
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
            // referans karti — kariyer ACIK gosterilir
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22D4AF37), GolrivaColors.card]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GolrivaColors.edge),
              ),
              child: Column(children: [
                Text('REFERANS KARİYER',
                    style: GoogleFonts.figtree(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        color: GolrivaColors.dim,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(engine.ref.ad.toUpperCase(),
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: 6),
                for (final kat in engine.tumKategoriler())
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(children: [
                      Expanded(
                        child: Text(kat.ad,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.figtree(
                                fontSize: 11, color: GolrivaColors.dim)),
                      ),
                      Text(kat.hedefGosterim,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GolrivaColors.goldHi)),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            if (!engine.bitti && !engine.soruKapandi) ...[
              // soru banner
              Center(
                child: Text(
                    '${engine.aktifSoru.ad} → ${engine.aktifSoru.hedefGosterim}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bigShouldersDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: GolrivaColors.goldHi,
                        letterSpacing: 1)),
              ),
              Center(
                child: Text('Bu değere EN YAKIN başka futbolcuyu yaz',
                    style: GoogleFonts.figtree(
                        fontSize: 11, color: GolrivaColors.dim)),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: kalanSn / ikizTurSaniye,
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
                    color: (yazan == 0 ? GolrivaColors.p1 : GolrivaColors.p2)
                        .withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                        color:
                            (yazan == 0 ? GolrivaColors.p1 : GolrivaColors.p2)
                                .withValues(alpha: .4)),
                  ),
                  child: Text(
                    '${adlar[yazan]} ${adlar[yazan] == "Sen" ? "yazıyorsun" : "yazıyor"}${engine.faz == 0 ? (adlar[yazan] == "Sen" ? " (önce sen)" : " (önce o)") : ""}',
                    style: GoogleFonts.figtree(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: yazan == 0 ? GolrivaColors.p1 : GolrivaColors.p2),
                  ),
                ),
              ),
              if (engine.faz == 1 && engine.cevap[engine.starter(engine.soru)] >= 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        '${adlar[engine.starter(engine.soru)]}: ${widget.repo.oyuncular[engine.cevap[engine.starter(engine.soru)]].ad}',
                        style: GoogleFonts.figtree(
                            fontSize: 11, color: GolrivaColors.dim)),
                  ),
                ),
              if (uyari != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(uyari!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: GolrivaColors.bad,
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
            if (engine.soruKapandi && !engine.bitti) ...[
              const SizedBox(height: 4),
              Center(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: GolrivaColors.gold,
                      foregroundColor: const Color(0xFF231A04),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12)),
                  onPressed: _sonraki,
                  child: Text(
                      engine.soru + 1 < ikizSoruSayisi
                          ? 'SONRAKİ SORU'
                          : 'SONUCU GÖR',
                      style: GoogleFonts.bigShouldersDisplay(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 16)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // acilan sorularin karsilastirma satirlari
            for (final s in engine.sonuclar) _sonucSatiri(s),
          ],
        ),
      ),
    );
  }

  Widget _sonucSatiri(IkizSonuc s) {
    Widget taraf(int p, Color renk) {
      final i = s.cevap[p];
      final kazandi = s.kazananS == p;
      return Expanded(
        child: Column(children: [
          Text(i >= 0 ? widget.repo.oyuncular[i].ad : '(boş)',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kazandi ? GolrivaColors.ok : renk)),
          Text(engine.cevapGoster(s.soru, i),
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kazandi ? GolrivaColors.ok : GolrivaColors.dim)),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: GolrivaColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GolrivaColors.edge2),
      ),
      child: Row(children: [
        taraf(0, GolrivaColors.p1),
        Column(children: [
          Text(s.soru.ad,
              style: GoogleFonts.figtree(
                  fontSize: 9,
                  letterSpacing: 1,
                  color: GolrivaColors.dim,
                  fontWeight: FontWeight.w700)),
          Text(s.soru.hedefGosterim,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.goldHi)),
        ]),
        taraf(1, GolrivaColors.p2),
      ]),
    );
  }

  Widget _adayRow(IkizAday a) {
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
            child: Text(a.neden ?? '${o.ulke} · ${o.dogumStr.substring(6)}',
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
