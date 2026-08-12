import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/kupa_repository.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import '../../widgets/saha_kadro.dart';
import 'engine.dart';

/// VETO DRAFTI ekranı (Faz 2.17) — Kupa Draftı + taktik veto katmanı.
/// Rakibin seçimini maçta 1 kez VETO edip yakabilirsin; veto edilen yeniden
/// seçilemez ve rakip aynı etap için yeni oyuncu arar. Hot-seat + çevrimiçi.
/// RESPONSIVE KURAL: kök yerleşim ListView.
class VetoDraftiScreen extends StatefulWidget {
  final KupaRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const VetoDraftiScreen({super.key, required this.repo, this.online});

  @override
  State<VetoDraftiScreen> createState() => _VetoDraftiScreenState();
}

class _VetoDraftiScreenState extends State<VetoDraftiScreen> {
  late VetoDraftEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<VetoAday> adaylar = [];
  String? sonAcilan;
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = secimSn;
  int sureLimit = secimSn;
  static const secimSn = 20;
  static const vetoSn = 10;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  /// Aktörlük: seçim aşamasında seçen, veto aşamasında vetocu.
  bool get siraBende =>
      widget.online == null ||
      engine.aktor == widget.online!.bilgi.benimSiram;

  String? get _siraNotu {
    if (widget.online == null || engine.bitti) return null;
    if (engine.asama == VetoAsama.veto) {
      return siraBende
          ? 'Rakibin seçimini gördün — VETO ile yakabilir ya da GEÇebilirsin.'
          : 'Rakip, seçimini veto edip etmeyeceğine karar veriyor.';
    }
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
    engine = VetoDraftEngine(widget.repo,
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
    if (tip != 'sec' && tip != 'veto' && tip != 'gec' && tip != 'sure') {
      return;
    }
    setState(() {
      if (tip == 'sec') {
        final idx = (h['idx'] as num).toInt();
        if (engine.sec(idx)) {
          final o = widget.repo.oyuncular[idx];
          sonAcilan = engine.asama == VetoAsama.veto
              ? '${adlar[engine.simdiSecen]} seçti: ${o.ad} — ${o.kupa} kupa'
              : '${o.ad} — ${o.kupa} kupa';
        }
      } else if (tip == 'veto') {
        final yanan = engine.adayIdx;
        if (engine.vetoYap() && yanan != null) {
          sonAcilan =
              'VETO! ${widget.repo.oyuncular[yanan].ad} yakıldı — yeniden seç';
        }
      } else if (tip == 'gec') {
        final idx = engine.adayIdx;
        if (engine.gec() && idx != null) {
          sonAcilan =
              '${widget.repo.oyuncular[idx].ad} — ${widget.repo.oyuncular[idx].kupa} kupa kesinleşti';
        }
      } else if (tip == 'sure') {
        if (engine.asama == VetoAsama.veto) {
          final idx = engine.adayIdx;
          if (engine.gec() && idx != null) {
            // veto süresi doldu = geç
            sonAcilan =
                'Veto süresi doldu — ${widget.repo.oyuncular[idx].ad} kesinleşti';
          }
        } else {
          engine.sureDoldu();
          sonAcilan = 'Süre doldu — etap boş geçti';
        }
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
    final sn = engine.asama == VetoAsama.veto ? vetoSn : secimSn;
    sureLimit = sn;
    kalanSn = sn;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        if (widget.online != null && !siraBende) {
          // aktörün süresi kendi istemcisinden bildirilir (hükmen ağı)
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && !siraBende) _macKapandi();
          });
          return;
        }
        widget.online?.gonder({'tip': 'sure'});
        setState(() {
          if (engine.asama == VetoAsama.veto) {
            engine.gec(); // veto penceresi doldu = geç
            sonAcilan = 'Veto süresi doldu — seçim kesinleşti';
          } else {
            engine.sureDoldu();
            sonAcilan = 'Süre doldu — etap boş geçti';
          }
          aramaCtrl.clear();
          adaylar = [];
        });
        _adimSonrasi();
      }
    });
  }

  void _sec(VetoAday a) {
    if (a.neden != null ||
        !siraBende ||
        engine.asama != VetoAsama.secim) {
      return;
    }
    final o = widget.repo.oyuncular[a.idx];
    setState(() {
      if (engine.sec(a.idx)) {
        widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
        sonAcilan = engine.asama == VetoAsama.veto
            ? '${o.ad} — ${o.kupa} kupa · rakip veto kararı veriyor'
            : '${o.ad} — ${o.kupa} kupa';
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    _adimSonrasi();
  }

  void _veto() {
    if (!siraBende || engine.asama != VetoAsama.veto) return;
    final yanan = engine.adayIdx;
    setState(() {
      if (engine.vetoYap() && yanan != null) {
        widget.online?.gonder({'tip': 'veto'});
        sonAcilan = 'VETO! ${widget.repo.oyuncular[yanan].ad} yakıldı';
      }
    });
    _adimSonrasi();
  }

  void _gec() {
    if (!siraBende || engine.asama != VetoAsama.veto) return;
    final idx = engine.adayIdx;
    setState(() {
      if (engine.gec() && idx != null) {
        widget.online?.gonder({'tip': 'gec'});
        sonAcilan =
            '${widget.repo.oyuncular[idx].ad} — ${widget.repo.oyuncular[idx].kupa} kupa kesinleşti';
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
                        ? 'Kupa sayıları eşit — rövanş şart.'
                        : '${(engine.toplam(0) - engine.toplam(1)).abs()} kupa farkla.',
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
                            engine = VetoDraftEngine(widget.repo);
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
        Text('kupa',
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
    final vetoAsamasi = !engine.bitti && engine.asama == VetoAsama.veto;
    return PopScope(
      // ONLINE maçta geri tuşu sessiz kaçış DEĞİL: çekilme onayı açılır.
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
            Text('VETO DRAFTI',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(
                engine.bitti
                    ? 'BİTTİ'
                    : 'TUR ${engine.tur + 1}/$vetoTurSayisi · VETO ${engine.vetoHak[0]}-${engine.vetoHak[1]}',
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
                    // önce kulüp adı, açıklama altında (tasarım kuralı)
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
                    const SizedBox(height: 4),
                    Text(
                        'BU KULÜPTE OYNAMIŞ EN KUPALI OYUNCUYU YAZ — RAKİP VETO EDEBİLİR',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 9,
                            letterSpacing: 2.5,
                            color: GolrivaColors.dim,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              const SizedBox(height: 10),
              if (!engine.bitti) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: kalanSn / sureLimit,
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
                if (sonAcilan != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(sonAcilan!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: sonAcilan!.startsWith('VETO')
                                ? GolrivaColors.bad
                                : GolrivaColors.goldHi,
                            letterSpacing: .5)),
                  ),
                ],
                const SizedBox(height: 8),
                // ── VETO PENCERESİ ──
                if (vetoAsamasi && engine.adayIdx != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GolrivaColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: GolrivaColors.bad.withValues(alpha: .5)),
                    ),
                    child: Column(children: [
                      Text(
                          '${adlar[engine.simdiSecen]} seçti: '
                          '${widget.repo.oyuncular[engine.adayIdx!].ad} — '
                          '${widget.repo.oyuncular[engine.adayIdx!].kupa} kupa',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.figtree(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: GolrivaColors.ink)),
                      const SizedBox(height: 4),
                      Text(
                          siraBende
                              ? 'Veto hakkın: ${engine.vetoHak[engine.vetocu]} — yakarsan rakip yeniden seçer, kimse alamaz.'
                              : '${adlar[engine.vetocu]} veto kararı veriyor…',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.figtree(
                              fontSize: 10.5, color: GolrivaColors.dim)),
                      if (siraBende) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      GolrivaColors.bad.withValues(alpha: .9),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12)),
                              onPressed: _veto,
                              child: Text('VETO!',
                                  style: GoogleFonts.bigShouldersDisplay(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      fontSize: 16)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: GolrivaColors.goldHi,
                                  side: const BorderSide(
                                      color: GolrivaColors.goldDeep),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12)),
                              onPressed: _gec,
                              child: Text('GEÇ',
                                  style: GoogleFonts.bigShouldersDisplay(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                      fontSize: 16)),
                            ),
                          ),
                        ]),
                      ],
                    ]),
                  ),
                // ── SEÇİM ARAMASI ──
                if (!vetoAsamasi) ...[
                  TextField(
                    // KLAVYE DUZELTMESI: sabit key — liste yapisi
                    // degisince eleman yeniden yaratilip odak/klavye dusuyordu.
                    key: const ValueKey('arama'),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('${engine.toplam(s)}',
                style: GoogleFonts.spaceGrotesk(
                    color: GolrivaColors.goldHi,
                    fontWeight: FontWeight.w700,
                    fontSize: 22)),
          ),
          Text('kupa · veto ${engine.vetoHak[s]}',
              style:
                  GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 9)),
        ]),
      );

  Widget _adayRow(VetoAday a) {
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
                // kupa sayısı META'DA YOK — tahmin konusu!
                a.neden ?? '${vetoSlotAd[o.poz]} · ${o.ulke}',
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

  /// SAHA GÖRÜNÜMÜ — kadro futbol sahasında (Kupa Draftı ile aynı dil).
  Widget _kadro(int s, Color renk) {
    final bySlot = <String, List<int>>{'K': [], 'D': [], 'O': [], 'F': []};
    for (final p in engine.kadrolar[s]) {
      bySlot[p.poz]!.add(p.idx);
    }
    List<SahaSlot> sira(String z) => List.generate(vetoFormation[z]!, (k) {
          final list = bySlot[z]!;
          final idx = k < list.length ? list[k] : null;
          return SahaSlot(
              poz: z,
              pozAd: vetoSlotAd[z]!,
              ad: idx == null ? null : widget.repo.oyuncular[idx].ad,
              deger:
                  idx == null ? null : '${widget.repo.oyuncular[idx].kupa}');
        });
    return SahaKadro(
      baslik: adlar[s].toUpperCase(),
      sagBilgi: '${engine.kadrolar[s].length}/$vetoTurSayisi',
      renk: renk,
      siralar: [sira('F'), sira('O'), sira('D'), sira('K')],
    );
  }
}
