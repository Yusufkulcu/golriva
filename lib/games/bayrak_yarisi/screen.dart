import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/players_repository.dart';
import '../../online/hata_raporu.dart';
import '../../online/mac_kanali.dart';
import '../../online/online_servis.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// BAYRAK YARISI ekrani — refleks yarisi.
/// Hot-seat: iki KAP butonu ayni ekranda. CEVRIMICI (Faz 2.14): her cihazda
/// TEK KAP butonu; kim once kapti kararini SUNUCU verir (bayrak_kap RPC —
/// tur basina tek kayit, ilk yazan kazanir; sure dolumu da ayni hakeme gider,
/// bu yuzden iki cihaz hicbir zaman farkli gerceklik goremez).
/// RESPONSIVE KURAL: kok yerlesim ListView.
class BayrakYarisiScreen extends StatefulWidget {
  final PlayersRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const BayrakYarisiScreen({super.key, required this.repo, this.online});

  @override
  State<BayrakYarisiScreen> createState() => _BayrakYarisiScreenState();
}

class _BayrakYarisiScreenState extends State<BayrakYarisiScreen> {
  late BayrakYarisiEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<BayrakAday> adaylar = [];
  String? turMesaji;
  Timer? sayac;
  Timer? gecisTimer;
  Timer? _hukmenTimer;
  int kalanSn = bayrakRaceSn;
  int sureLimit = bayrakRaceSn;
  bool _kapBekliyor = false; // hakem cevabi bekleniyor (cift tiklama kalkani)
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  int get _benimSeat => widget.online?.bilgi.benimSiram ?? 0;
  int get _rakipSeat => 1 - _benimSeat;
  bool get _claimerBenim =>
      widget.online == null || engine.claimer == _benimSeat;

  @override
  void initState() {
    super.initState();
    final o = widget.online;
    adlar = o == null
        ? ['Sen', 'Rakip']
        : (o.bilgi.benimSiram == 0
            ? ['Sen', o.bilgi.rakipAdi]
            : [o.bilgi.rakipAdi, 'Sen']);
    engine = BayrakYarisiEngine(widget.repo,
        rng: o == null ? null : Random(o.bilgi.seed));
    o?.basla(_rakipHamle, onMacKapandi: _macKapandi);
    _raceBaslat();
  }

  /// Rakip cekildi ya da mac sunucuda kapandi.
  void _macKapandi() {
    if (!mounted || _kapanisIslendi) return;
    if (engine.bitti) {
      if (!_sonucAcik) _sonucGoster(); // kurtarma agi
      return;
    }
    _kapanisIslendi = true;
    sayac?.cancel();
    gecisTimer?.cancel();
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
                  kanal: widget.online!, kazananSeat: _benimSeat),
            ]),
          ),
        ),
      ),
    );
  }

  /// Done (tur ozeti) sirasinda gelen rakip olaylari: rakip 2,6 sn'lik
  /// gecisi bizden once tamamlayip yeni turda oynamis olabilir — olay
  /// YUTULMAZ, tur gecisinden sonra sirayla uygulanir.
  final List<Map<String, dynamic>> _bekleyenler = [];

  void _rakipHamle(Map<String, dynamic> h) {
    if (!mounted || engine.bitti) return;
    _hukmenTimer?.cancel();
    final tip = h['tip'];
    if (tip == 'cekildi') {
      _macKapandi();
      return;
    }
    if (tip != 'kap' &&
        tip != 'cevap' &&
        tip != 'yanlis' &&
        tip != 'pas' &&
        tip != 'sure_doldu') {
      return;
    }
    if (engine.mod == BayrakMod.done) {
      _bekleyenler.add(h);
      return;
    }
    switch (tip) {
      case 'kap':
        final s = (h['seat'] as num).toInt();
        if (engine.mod == BayrakMod.race && engine.kap(s)) {
          setState(() => turMesaji = '${adlar[s]} kaptı!');
          _cevapAkisi();
        }
      case 'cevap':
        final idx = (h['idx'] as num).toInt();
        final kazananS = engine.claimer;
        if (engine.cevapVer(idx)) {
          sayac?.cancel();
          setState(() {
            turMesaji =
                'DOĞRU! ${widget.repo.oyuncular[idx].ad} — turu ${adlar[kazananS]} aldı';
          });
          _turSonuGecis();
        }
      case 'yanlis':
        _hakDus('yanlış oyuncu seçti', bildir: false);
      case 'pas':
        _hakDus('pas geçti', bildir: false);
      case 'sure_doldu':
        _hakDus('süre doldu', bildir: false);
    }
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
    _kapBekliyor = false;
    _sayacKur(bayrakRaceSn, () {
      if (widget.online == null) {
        setState(() {
          engine.raceSuresiDoldu();
          turMesaji = 'Kimse cesaret edemedi';
        });
        _turSonuGecis();
      } else {
        // SURE DOLUMU DA HAKEME GIDER: son milisaniyede kapan gercek oyuncu
        // "bos" kararini yener — iki cihaz ayni karari gorur.
        _hakemeSor(bosMu: true);
      }
    });
  }

  /// SUNUCU HAKEMI: bu turun tek kararini al (kap ya da bos), sonucu uygula.
  /// Ag hatasi olursa ayni tur icin 1,5 sn sonra yeniden sorulur.
  Future<void> _hakemeSor({required bool bosMu}) async {
    final turNo = engine.tur;
    if (_kapBekliyor && !bosMu) return;
    if (!bosMu) setState(() => _kapBekliyor = true);
    try {
      final r = await OnlineServis()
          .bayrakKap(widget.online!.bilgi.macId, turNo, bosMu: bosMu);
      if (!mounted || engine.bitti) return;
      // tur ilerlediyse (rakip olayi bizden once geldiyse) karar eski — at
      if (engine.tur != turNo || engine.mod != BayrakMod.race) return;
      final benimUid = widget.online!.bilgi.seatUid(_benimSeat);
      if (r.bos) {
        sayac?.cancel();
        setState(() {
          engine.raceSuresiDoldu();
          turMesaji = 'Kimse cesaret edemedi';
        });
        _turSonuGecis();
      } else if (r.sahip == benimUid) {
        sayac?.cancel();
        engine.kap(_benimSeat);
        widget.online!
            .gonder({'tip': 'kap', 'tur': turNo, 'seat': _benimSeat});
        setState(() {
          turMesaji = 'KAPTIN! Şimdi yaz';
          aramaCtrl.clear();
          adaylar = [];
        });
        _cevapAkisi();
      } else if (r.sahip != null) {
        sayac?.cancel();
        engine.kap(_rakipSeat);
        setState(() => turMesaji = '${adlar[_rakipSeat]} önce kaptı!');
        _cevapAkisi();
      }
    } catch (e, s) {
      hataBildir('bayrak._hakem', e, s);
      if (!mounted || engine.bitti) return;
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted &&
            !engine.bitti &&
            engine.tur == turNo &&
            engine.mod == BayrakMod.race) {
          _hakemeSor(bosMu: bosMu);
        } else if (mounted && !bosMu) {
          setState(() => _kapBekliyor = false);
        }
      });
      return;
    }
    if (mounted) setState(() => _kapBekliyor = false);
  }

  /// KAP basildi (hot-seat: s = basan koltuk; online: hep benim koltuk).
  void _kap(int s) {
    if (widget.online != null) {
      if (engine.mod != BayrakMod.race ||
          engine.denenen.contains(_benimSeat) ||
          _kapBekliyor) {
        return;
      }
      _hakemeSor(bosMu: false);
      return;
    }
    if (!engine.kap(s)) return;
    setState(() {
      aramaCtrl.clear();
      adaylar = [];
    });
    _cevapSayaci();
  }

  /// Cevap fazi baslangici: yazan benim ise sayac, rakipse hukmen beklemesi.
  void _cevapAkisi() {
    aramaCtrl.clear();
    adaylar = [];
    if (_claimerBenim) {
      _cevapSayaci();
    } else {
      // rakibin cevabi kendi cihazindan bildirilir; 10+15 sn sessizlik =
      // rakip ayrildi (hukmen)
      _sayacKur(bayrakCevapSn, () {});
      _hukmenTimer?.cancel();
      _hukmenTimer = Timer(const Duration(seconds: bayrakCevapSn + 15), () {
        if (mounted && !engine.bitti && !_claimerBenim) _macKapandi();
      });
    }
  }

  void _cevapSayaci() {
    _sayacKur(bayrakCevapSn, () {
      widget.online?.gonder({'tip': 'sure_doldu', 'tur': engine.tur});
      _hakDus('süre doldu', bildir: false);
    });
  }

  void _hakDus(String neden, {bool bildir = true}) {
    if (engine.mod != BayrakMod.answer) return;
    final oncekiClaimer = engine.claimer;
    setState(() {
      aramaCtrl.clear();
      adaylar = [];
      if (engine.hakDus()) {
        turMesaji =
            '${adlar[oncekiClaimer]} — $neden! Hak ${adlar[engine.claimer]}\'de';
        if (widget.online == null) {
          _cevapSayaci();
        } else {
          _cevapAkisi();
        }
      } else {
        turMesaji = 'İkisi de bilemedi';
        _turSonuGecis();
      }
    });
  }

  void _sec(BayrakAday a) {
    if (a.neden != null || !_claimerBenim) return;
    final kazananS = engine.claimer;
    final o = widget.repo.oyuncular[a.idx];
    if (engine.cevapVer(a.idx)) {
      sayac?.cancel();
      widget.online?.gonder({'tip': 'cevap', 'idx': a.idx, 'tur': engine.tur});
      setState(() {
        turMesaji =
            'DOĞRU! ${o.ad} — turu ${adlar[kazananS]} aldı';
        aramaCtrl.clear();
        adaylar = [];
      });
      _turSonuGecis();
    } else {
      // KURAL (kullanici, 30 Tem): yanlis oyuncu = hak rakibe gecer
      widget.online?.gonder({'tip': 'yanlis', 'idx': a.idx, 'tur': engine.tur});
      _hakDus('yanlış oyuncu seçti', bildir: false);
    }
  }

  void _pas() {
    if (!_claimerBenim) return;
    widget.online?.gonder({'tip': 'pas', 'tur': engine.tur});
    _hakDus('pas geçti', bildir: false);
  }

  void _turSonuGecis() {
    sayac?.cancel();
    gecisTimer?.cancel();
    gecisTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || _kapanisIslendi) return;
      setState(() {
        engine.sonrakiTur();
        if (!engine.bitti) _raceBaslat();
      });
      if (engine.bitti) {
        _sonucGoster();
        return;
      }
      // done sirasinda biriken rakip olaylarini simdi uygula
      if (_bekleyenler.isNotEmpty) {
        final b = List.of(_bekleyenler);
        _bekleyenler.clear();
        for (final h in b) {
          _rakipHamle(h);
        }
      }
    });
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
      ),
    );
  }

  @override
  void dispose() {
    sayac?.cancel();
    gecisTimer?.cancel();
    _hukmenTimer?.cancel();
    widget.online?.kapat();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final race = engine.mod == BayrakMod.race;
    final answer = engine.mod == BayrakMod.answer;
    return PopScope(
      // ONLINE macta geri tusu sessiz kacis DEGIL: cekilme onayi acilir.
      canPop: widget.online == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.online != null) {
          cekilAkisi(context, widget.online!, onCekildi: () {
            sayac?.cancel();
            gecisTimer?.cancel();
            _hukmenTimer?.cancel();
          });
        }
      },
      child: Scaffold(
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
        actions: [
          if (widget.online != null)
            IconButton(
                tooltip: 'Maçtan çekil',
                icon: const Icon(Icons.flag_outlined,
                    color: GolrivaColors.dim, size: 20),
                onPressed: () => cekilAkisi(context, widget.online!,
                    onCekildi: () {
                      sayac?.cancel();
                      gecisTimer?.cancel();
                      _hukmenTimer?.cancel();
                    })),
        ],
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
              if (race && widget.online == null)
                Row(children: [
                  Expanded(child: _kapButonu(0, GolrivaColors.p1)),
                  const SizedBox(width: 10),
                  Expanded(child: _kapButonu(1, GolrivaColors.p2)),
                ]),
              if (race && widget.online != null)
                // ONLINE: tek KAP — kararı sunucu verir (ilk yazan kazanır)
                _kapButonu(_benimSeat,
                    _benimSeat == 0 ? GolrivaColors.p1 : GolrivaColors.p2),
              if (answer) ...[
                if (widget.online != null) ...[
                  SiraSeridi(
                      siraBende: _claimerBenim,
                      rakipAdi: widget.online!.bilgi.rakipAdi,
                      notu: _claimerBenim
                          ? 'Kaptın — $bayrakCevapSn saniyede yaz!'
                          : 'Rakip kaptı — cevabını bekle'),
                  const SizedBox(height: 8),
                ],
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
                  enabled: _claimerBenim,
                  onChanged: (v) =>
                      setState(() => adaylar = engine.adaylar(v)),
                  decoration: InputDecoration(
                      hintText: _claimerBenim
                          ? 'Futbolcu adı yaz… (en az 3 harf)'
                          : '${adlar[engine.claimer]} yazıyor…',
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
                if (_claimerBenim) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: GolrivaColors.dim,
                          side: const BorderSide(color: GolrivaColors.edge2)),
                      onPressed: _pas,
                      child: Text('PAS',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w800, letterSpacing: 2)),
                    ),
                  ),
                ],
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
    final kullanildi =
        engine.denenen.contains(s) || (widget.online != null && _kapBekliyor);
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
      child: Text(
          widget.online != null
              ? (_kapBekliyor ? 'HAKEM…' : 'KAP!')
              : '${adlar[s].toUpperCase()} KAP!',
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
