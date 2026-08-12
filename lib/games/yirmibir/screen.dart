import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/kor_av_repository.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// BONSERVİS 21'İ ekranı (Faz 2.17) — blackjack gerilimli kör av.
/// Sırayla futbolcu çekilir (bonservis seçimde AÇILIR, toplam üstte birikir)
/// ya da DUR denir. Hedefi AŞAN YANAR ve maç ANINDA biter — yanan direkt
/// kaybeder. Hot-seat + çevrimiçi.
/// RESPONSIVE KURAL: kök yerleşim ListView.
class YirmibirScreen extends StatefulWidget {
  final KorAvRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const YirmibirScreen({super.key, required this.repo, this.online});

  @override
  State<YirmibirScreen> createState() => _YirmibirScreenState();
}

class _YirmibirScreenState extends State<YirmibirScreen> {
  late YirmibirEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<YirmibirAday> adaylar = [];
  String? uyari;
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = 20;
  static const turSn = 20;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  bool get siraBende =>
      widget.online == null || engine.sira == widget.online!.bilgi.benimSiram;

  /// Rakip elini kapattıysa art arda seçimler bende — açıkla.
  /// (Yanma durumu yok: yanan anında kaybeder, maç biter.)
  String? get _siraNotu {
    if (widget.online == null || engine.bitti) return null;
    final diger = 1 - engine.sira;
    if (engine.durdu[diger]) {
      return siraBende
          ? 'Rakip DUR dedi — art arda seçimler sende.'
          : 'Elini kapattın — rakip devam ediyor.';
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
    engine = YirmibirEngine(widget.repo,
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
    if (h['tip'] == 'cekildi') {
      _macKapandi();
      return;
    }
    if (h['tip'] != 'sec' && h['tip'] != 'dur' && h['tip'] != 'sure') return;
    setState(() {
      if (h['tip'] == 'sec') {
        final idx = (h['idx'] as num).toInt();
        final cekenS = engine.sira;
        if (engine.sec(idx)) {
          final o = widget.repo.oyuncular[idx];
          uyari = engine.yandi[cekenS]
              ? '${o.ad} — ${_fmt(o.deger)} M€ · ${adlar[cekenS]} YANDI!'
              : '${o.ad} — ${_fmt(o.deger)} M€';
        }
      } else {
        // 'dur' ve 'sure' aynı sonuç: rakip elini kapattı
        uyari = '${adlar[engine.sira]} DUR dedi';
        engine.dur();
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
          // rakibin süresi rakibin istemcisinden bildirilir (hükmen ağı)
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && !siraBende) _macKapandi();
          });
          return;
        }
        // süre dolumu = otomatik DUR (karar vermemek de bir karardır)
        widget.online?.gonder({'tip': 'sure'});
        setState(() {
          uyari = '${adlar[engine.sira]} — süre doldu, el kapandı';
          engine.dur();
          aramaCtrl.clear();
          adaylar = [];
        });
        _adimSonrasi();
      }
    });
  }

  void _sec(YirmibirAday a) {
    if (a.neden != null || !siraBende || engine.durdu[engine.sira]) return;
    final o = widget.repo.oyuncular[a.idx];
    final cekenS = engine.sira;
    setState(() {
      if (engine.sec(a.idx)) {
        widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
        uyari = engine.yandi[cekenS]
            ? '${o.ad} — ${_fmt(o.deger)} M€ · YANDIN!'
            : '${o.ad} — ${_fmt(o.deger)} M€';
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    _adimSonrasi();
  }

  void _dur() {
    if (!siraBende || engine.bitti || engine.durdu[engine.sira]) return;
    widget.online?.gonder({'tip': 'dur'});
    setState(() {
      uyari = 'Elini kapattın';
      engine.dur();
      aramaCtrl.clear();
      adaylar = [];
    });
    _adimSonrasi();
  }

  void _sonucGoster() {
    if (!mounted) return;
    _sonucAcik = true;
    final k = engine.kazanan();
    final aciklama = k == null
        ? 'İkiniz de hedefe eşit uzaktasınız.'
        : engine.yandi[1 - k]
            ? '${adlar[1 - k]} hedefi aştı — yandı.'
            : '${adlar[k]} ${_fmt(engine.fark(k))} M€ farkla daha yakın.';
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
                      _sonucKutu(0, GolrivaColors.p1),
                      _sonucKutu(1, GolrivaColors.p2),
                    ]),
                const SizedBox(height: 8),
                Text('Hedef ${engine.hedef} M€ — $aciklama',
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
                            engine = YirmibirEngine(widget.repo);
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

  Widget _sonucKutu(int s, Color renk) => Column(children: [
        Text(adlar[s].toUpperCase(),
            style: GoogleFonts.figtree(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1)),
        Text(_fmt(engine.toplam(s)),
            style: GoogleFonts.spaceGrotesk(
                color: engine.yandi[s]
                    ? GolrivaColors.bad
                    : GolrivaColors.goldHi,
                fontWeight: FontWeight.w700,
                fontSize: 26)),
        Text(engine.yandi[s] ? 'YANDI' : 'fark ${_fmt(engine.fark(s))}',
            style: GoogleFonts.figtree(
                color:
                    engine.yandi[s] ? GolrivaColors.bad : GolrivaColors.dim,
                fontSize: 10)),
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
    final oynayabilirim =
        !engine.bitti && siraBende && !engine.durdu[engine.sira];
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
            Text('BONSERVİS 21\'İ',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(engine.bitti ? 'BİTTİ' : 'YAKLAŞ AMA AŞMA',
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
              // hedef kartı — büyük değer üstte, açıklama altta
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
                    child: Text('${engine.hedef} M€',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: GolrivaColors.goldHi)),
                  ),
                  const SizedBox(height: 4),
                  Text('HEDEFE EN ÇOK YAKLAŞAN KAZANIR — AŞAN ANINDA KAYBEDER',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: GolrivaColors.dim,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 10),
              if (widget.online != null && !engine.bitti) ...[
                SiraSeridi(
                    siraBende: siraBende,
                    rakipAdi: widget.online!.bilgi.rakipAdi,
                    notu: _siraNotu),
                const SizedBox(height: 10),
              ],
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
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: (engine.sira == 0
                              ? GolrivaColors.p1
                              : GolrivaColors.p2)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: (engine.sira == 0
                                  ? GolrivaColors.p1
                                  : GolrivaColors.p2)
                              .withValues(alpha: .4)),
                    ),
                    child: Text(
                      '${adlar[engine.sira]} ${adlar[engine.sira] == "Sen" ? "karar veriyorsun" : "karar veriyor"} · seçim ${engine.secimler[engine.sira].length}/$yirmibirMaxSecim',
                      style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: engine.sira == 0
                              ? GolrivaColors.p1
                              : GolrivaColors.p2),
                    ),
                  ),
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
                          color: uyari!.contains('YANDI')
                              ? GolrivaColors.bad
                              : GolrivaColors.goldHi,
                          letterSpacing: .5)),
                ),
              ],
              if (!engine.bitti) ...[
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
                          ? 'Futbolcu adı yaz… (en az 3 harf)'
                          : '${adlar[engine.sira]} oynuyor…',
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
                if (oynayabilirim) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: GolrivaColors.goldHi,
                          side:
                              const BorderSide(color: GolrivaColors.goldDeep),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10)),
                      onPressed: _dur,
                      child: Text('DUR',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 16)),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti && engine.sira == 0,
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p1,
                        child: _taraf(0, GolrivaColors.p1))),
                const SizedBox(width: 10),
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti && engine.sira == 1,
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p2,
                        child: _taraf(1, GolrivaColors.p2))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adayRow(YirmibirAday a) {
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
                // DEĞER META'DA YOK — kör mekanik!
                a.neden ??
                    '${o.mevkiAd} · ${o.ulke}${o.dogumYili > 0 ? " · ${o.dogumYili}" : ""}',
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

  /// Taraf paneli: seçilenler AÇIK değerleriyle listelenir, toplam altta.
  Widget _taraf(int s, Color renk) {
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
          if (engine.yandi[s])
            Text('YANDI',
                style: GoogleFonts.figtree(
                    color: GolrivaColors.bad,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1))
          else if (engine.durdu[s])
            Text('DURDU',
                style: GoogleFonts.figtree(
                    color: GolrivaColors.dim,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1)),
        ]),
        const SizedBox(height: 6),
        if (engine.secimler[s].isEmpty)
          Text('— henüz seçim yok —',
              style:
                  GoogleFonts.figtree(fontSize: 11, color: GolrivaColors.dim2))
        else
          for (final i in engine.secimler[s])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(children: [
                Expanded(
                  child: Text(widget.repo.oyuncular[i].ad,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                          fontSize: 11.5, color: GolrivaColors.ink)),
                ),
                Text(_fmt(widget.repo.oyuncular[i].deger),
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
          Text('${_fmt(engine.toplam(s))} M€',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: engine.yandi[s]
                      ? GolrivaColors.bad
                      : GolrivaColors.goldHi)),
        ]),
      ]),
    );
  }
}

/// Değer gösterimi: tam sayıysa "120", değilse "117,5" (TR virgül).
String _fmt(double v) => v % 1 == 0
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1).replaceAll('.', ',');
