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

/// ŞL GECESİ ekranı (Faz 2.18) — Şampiyonlar Ligi temalı kör seçim.
/// Her turun kategorisi (ŞL GOLÜ / ŞL ASİSTİ) büyük yazılır; seçilen
/// futbolcunun o kategorideki sayısı açılıp toplama eklenir.
/// Hot-seat + çevrimiçi. RESPONSIVE KURAL: kök yerleşim ListView.
class SlGecesiScreen extends StatefulWidget {
  final IkizRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const SlGecesiScreen({super.key, required this.repo, this.online});

  @override
  State<SlGecesiScreen> createState() => _SlGecesiScreenState();
}

class _SlGecesiScreenState extends State<SlGecesiScreen> {
  late SlGecesiEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<SlAday> adaylar = [];
  String? uyari;
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = turSn;
  static const turSn = 20;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  bool get siraBende =>
      widget.online == null ||
      engine.simdiSecen == widget.online!.bilgi.benimSiram;

  String? get _siraNotu {
    if (widget.online == null || engine.bitti) return null;
    if (engine.faz == 0 && engine.tur > 0) {
      return siraBende
          ? 'Draft kuralı: her turda ilk seçen değişir — üst üste iki seçim sende.'
          : 'Draft kuralı: her turda ilk seçen değişir — rakip üst üste seçiyor.';
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
    engine = SlGecesiEngine(widget.repo,
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
        final idx = (h['idx'] as num).toInt();
        final secen = engine.simdiSecen;
        final k = engine.katki(idx);
        final kd = engine.kategoriAd;
        if (engine.sec(idx)) {
          uyari =
              '${widget.repo.oyuncular[idx].ad} — $k $kd (${adlar[secen]})';
        }
      } else {
        final secen = engine.simdiSecen;
        engine.sureDoldu();
        uyari = '${adlar[secen]} süreyi doldurdu — etap boş geçti';
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
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
          final secen = engine.simdiSecen;
          engine.sureDoldu();
          uyari = '${adlar[secen]} — süre doldu, etap boş geçti';
          aramaCtrl.clear();
          adaylar = [];
        });
        _adimSonrasi();
      }
    });
  }

  void _sec(SlAday a) {
    if (a.neden != null || !siraBende || engine.bitti) return;
    final o = widget.repo.oyuncular[a.idx];
    final k = engine.katki(a.idx);
    final kd = engine.kategoriAd;
    setState(() {
      if (engine.sec(a.idx)) {
        widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
        uyari = '${o.ad} — $k $kd';
        aramaCtrl.clear();
        adaylar = [];
      }
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
                      _toplamKutu(0, GolrivaColors.p1),
                      _toplamKutu(1, GolrivaColors.p2),
                    ]),
                const SizedBox(height: 8),
                Text(
                    k == null
                        ? 'ŞL katkıları eşit — rövanş şart.'
                        : '${(engine.toplam(0) - engine.toplam(1)).abs()} katkı farkla.',
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
                            engine = SlGecesiEngine(widget.repo);
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
        Text('ŞL katkısı',
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
    final secen = engine.bitti ? 0 : engine.simdiSecen;
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
            Text('ŞL GECESİ',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(
                engine.bitti
                    ? 'BİTTİ'
                    : 'TUR ${engine.tur + 1}/$slTurSayisi · ${engine.kategoriAd}',
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
                        aktif: !engine.bitti && engine.simdiSecen == 0,
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p1,
                        child: _taraf(0, GolrivaColors.p1))),
                const SizedBox(width: 10),
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti && engine.simdiSecen == 1,
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p2,
                        child: _taraf(1, GolrivaColors.p2))),
              ]),
              if (widget.online != null && !engine.bitti) ...[
                const SizedBox(height: 10),
                SiraSeridi(
                    siraBende: siraBende,
                    rakipAdi: widget.online!.bilgi.rakipAdi,
                    notu: _siraNotu),
              ],
              const SizedBox(height: 10),
              if (!engine.bitti) ...[
                // ── KATEGORİ KARTI: büyük ad üstte, açıklama altta ──
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x22224FD4), GolrivaColors.card]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: GolrivaColors.edge),
                  ),
                  child: Column(children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(engine.kategoriAd,
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        engine.kategori == SlKategori.gol
                            ? 'ŞAMPİYONLAR LİGİ\'NDE ÇOK GOL ATMIŞ BİR FUTBOLCU YAZ'
                            : 'ŞAMPİYONLAR LİGİ\'NDE ÇOK ASİST YAPMIŞ BİR FUTBOLCU YAZ',
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
                          color: GolrivaColors.goldHi,
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
                          : '${adlar[secen]} oynuyor…',
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
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Taraf paneli: seçilenler kategorileriyle AÇIK listelenir, toplam altta.
  Widget _taraf(int s, Color renk) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GolrivaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GolrivaColors.edge2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(adlar[s].toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.figtree(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1)),
        const SizedBox(height: 6),
        if (engine.secimler[s].isEmpty)
          Text('— henüz seçim yok —',
              style:
                  GoogleFonts.figtree(fontSize: 11, color: GolrivaColors.dim2))
        else
          for (final (idx, k) in engine.secimler[s])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(children: [
                Expanded(
                  child: Text(widget.repo.oyuncular[idx].ad,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                          fontSize: 11.5, color: GolrivaColors.ink)),
                ),
                Text('$k',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: GolrivaColors.goldHi)),
              ]),
            ),
        const Divider(color: GolrivaColors.edge2, height: 14),
        Row(children: [
          Expanded(
            child: Text('TOPLAM',
                style: GoogleFonts.figtree(
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.dim)),
          ),
          Text('${engine.toplam(s)}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.goldHi)),
        ]),
      ]),
    );
  }

  Widget _adayRow(SlAday a) {
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
                // ŞL sayıları META'DA YOK — tahmin konusu!
                a.neden ?? o.ulke,
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
