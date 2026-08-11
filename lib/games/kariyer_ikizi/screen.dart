import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/ikiz_repository.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// KARIYER IKIZI ekrani — 5 soruluk kariyer tahmin duellosu.
/// Referans kariyeri acik; her soruda hedefe EN YAKIN futbolcuyu yazan puani
/// alir. Hot-seat + CEVRIMICI (Faz 2.14): ayni seed = ayni referans/sorular,
/// hamleler kanaldan senkronlanir. RESPONSIVE KURAL: kok yerlesim ListView.
class KariyerIkiziScreen extends StatefulWidget {
  final IkizRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const KariyerIkiziScreen({super.key, required this.repo, this.online});

  @override
  State<KariyerIkiziScreen> createState() => _KariyerIkiziScreenState();
}

class _KariyerIkiziScreenState extends State<KariyerIkiziScreen> {
  late KariyerIkiziEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<IkizAday> adaylar = [];
  String? uyari;
  Timer? sayac;
  Timer? _hukmenTimer; // rakip kayboldu mu?
  Timer? _gecisTimer; // online: reveal sonrasi otomatik sonraki soru
  int kalanSn = ikizTurSaniye;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false; // sonuç diyaloğu ekranda mı

  bool get siraBende =>
      widget.online == null ||
      engine.simdiYazan == widget.online!.bilgi.benimSiram;

  /// Soru kuralı üst üste yazmaya yol açtığında açıkla (sıra karmaşası olmasın).
  String? get _siraNotu {
    if (widget.online == null || engine.bitti || engine.soruKapandi) {
      return null;
    }
    if (engine.faz == 0 && engine.soru > 0) {
      return siraBende
          ? 'Kural: her soruda ilk yazan değişir — bu soruda önce sen.'
          : 'Kural: her soruda ilk yazan değişir — bu soruda önce rakip.';
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
    engine = KariyerIkiziEngine(widget.repo,
        rng: o == null ? null : Random(o.bilgi.seed));
    o?.basla(_rakipHamle, onMacKapandi: _macKapandi);
    _sayacBaslat();
  }

  /// Rakip cekildi ya da mac sunucuda kapandi: hukmen kazanan biziz.
  void _macKapandi() {
    if (!mounted || _kapanisIslendi) return;
    if (engine.bitti) {
      // KURTARMA AĞI: sonuç diyaloğu her nasılsa açılmadıysa şimdi aç.
      if (!_sonucAcik) _sonucGoster();
      return;
    }
    _kapanisIslendi = true;
    sayac?.cancel();
    _gecisTimer?.cancel();
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

  /// Reveal (soruKapandi) sirasinda gelen rakip hamleleri: rakip 3,5 sn'lik
  /// gecisi bizden ONCE tamamlayip yeni soruda oynamis olabilir — hamle
  /// YUTULMAZ, soru gecisinden sonra sirayla uygulanir (senkron garantisi).
  final List<Map<String, dynamic>> _bekleyenHamleler = [];

  void _rakipHamle(Map<String, dynamic> h) {
    if (!mounted || engine.bitti) return;
    _hukmenTimer?.cancel();
    if (h['tip'] == 'cekildi') {
      _macKapandi();
      return;
    }
    if (h['tip'] != 'sec' && h['tip'] != 'sure') return;
    if (engine.soruKapandi) {
      _bekleyenHamleler.add(h);
      return;
    }
    setState(() {
      if (h['tip'] == 'sec') {
        engine.sec((h['idx'] as num).toInt());
      } else {
        engine.sureDoldu();
        uyari = '${adlar[1 - widget.online!.bilgi.benimSiram]} — süre doldu';
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
  }

  /// Hamle sonrasi ortak akis: soru kapandiysa reveal + (online) otomatik
  /// gecis; degilse sayac yeniden.
  void _adimSonrasi() {
    if (engine.soruKapandi) {
      sayac?.cancel();
      if (widget.online != null) {
        _gecisTimer?.cancel();
        _gecisTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted && !_kapanisIslendi) _sonraki();
        });
      }
    } else {
      _sayacBaslat();
    }
  }

  void _sayacBaslat() {
    sayac?.cancel();
    kalanSn = ikizTurSaniye;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        if (widget.online != null && !siraBende) {
          // Rakibin süresi rakibin istemcisinden bildirilir; 15 sn içinde
          // hiçbir hamle gelmezse rakip ayrılmış sayılır (hükmen).
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && !siraBende) _macKapandi();
          });
          return;
        }
        widget.online?.gonder({'tip': 'sure'});
        setState(() {
          uyari = '${adlar[engine.simdiYazan]} — süre doldu, cevapsız';
          engine.sureDoldu();
          aramaCtrl.clear();
          adaylar = [];
        });
        _adimSonrasi();
      }
    });
  }

  void _sec(IkizAday a) {
    if (a.neden != null || !siraBende) return;
    setState(() {
      if (engine.sec(a.idx)) {
        widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
        uyari = null;
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    _adimSonrasi();
  }

  void _sonraki() {
    _gecisTimer?.cancel();
    setState(() {
      engine.sonrakiSoru();
      uyari = null;
    });
    if (engine.bitti) {
      sayac?.cancel();
      _sonucGoster();
      return;
    }
    _sayacBaslat();
    // reveal sirasinda biriken rakip hamleleri simdi uygula
    if (_bekleyenHamleler.isNotEmpty) {
      final b = List.of(_bekleyenHamleler);
      _bekleyenHamleler.clear();
      for (final h in b) {
        _rakipHamle(h);
      }
    }
  }

  void _sonucGoster() {
    if (!mounted) return;
    _sonucAcik = true;
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
              if (widget.online != null)
                OnlineSonucButonlari(kanal: widget.online!, kazananSeat: k)
              else
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
    _hukmenTimer?.cancel();
    _gecisTimer?.cancel();
    widget.online?.kapat();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yazan = engine.bitti || engine.soruKapandi ? 0 : engine.simdiYazan;
    return PopScope(
      // ONLINE macta geri tusu sessiz kacis DEGIL: cekilme onayi acilir.
      canPop: widget.online == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.online != null) {
          cekilAkisi(context, widget.online!, onCekildi: () {
            sayac?.cancel();
            _hukmenTimer?.cancel();
            _gecisTimer?.cancel();
          });
        }
      },
      child: Scaffold(
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
                      _gecisTimer?.cancel();
                    })),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            if (widget.online != null &&
                !engine.bitti &&
                !engine.soruKapandi) ...[
              SiraSeridi(
                  siraBende: siraBende,
                  rakipAdi: widget.online!.bilgi.rakipAdi,
                  notu: _siraNotu),
              const SizedBox(height: 10),
            ],
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
                enabled: !engine.bitti && !engine.soruKapandi && siraBende,
                onChanged: (v) => setState(() => adaylar = engine.adaylar(v)),
                decoration: InputDecoration(
                    hintText: siraBende
                        ? 'Futbolcu adı yaz… (en az 3 harf)'
                        : '${adlar[yazan]} yazıyor…',
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
                          const Divider(height: 1, color: GolrivaColors.edge2),
                        _adayRow(adaylar[i]),
                      ],
                    ]),
                  ),
                ),
            ],
            if (engine.soruKapandi && !engine.bitti) ...[
              const SizedBox(height: 4),
              if (widget.online != null)
                // ONLINE: iki cihaz da sabit gecikmeyle otomatik ilerler —
                // elle erken geçiş senkronu bozardı (buton yok).
                Center(
                  child: Text('Sonraki soru birazdan…',
                      style: GoogleFonts.figtree(
                          fontSize: 11.5, color: GolrivaColors.dim)),
                )
              else
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
            // GÜVENLİK: yalnız ülke — doğum yılı/tarihi ASLA gösterilmez;
            // "DOĞUM TARİHİ" sorusunda cevabı ele veriyordu (kullanıcı raporu).
            child: Text(a.neden ?? o.ulke,
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

