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

/// KUPA DRAFTI ekrani — hot-seat draft. Kupa sayisi secimde ANINDA acilir,
/// toplam ustte birikir, YUKSEK kazanir. RESPONSIVE KURAL: kok ListView.
class KupaDraftiScreen extends StatefulWidget {
  final KupaRepository repo;
  final OnlineMacKanali? online; // null = hot-seat
  const KupaDraftiScreen({super.key, required this.repo, this.online});

  @override
  State<KupaDraftiScreen> createState() => _KupaDraftiScreenState();
}

class _KupaDraftiScreenState extends State<KupaDraftiScreen> {
  late KupaDraftEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<KupaAday> adaylar = [];
  String? sonAcilan;
  Timer? sayac;
  Timer? _hukmenTimer; // rakip kayboldu mu? (hukmen)
  int kalanSn = 20;
  static const turSn = 20;

  bool get siraBende =>
      widget.online == null ||
      engine.simdiSecen == widget.online!.bilgi.benimSiram;

  /// Snake-draft kuralı (her turda ilk seçen değişir) aynı oyuncuya üst üste
  /// iki seçim getirir — bunu açıkça söylemezsek "sıra iki kere geçti" diye
  /// hata sanılıyor (kullanıcı geri bildirimi).
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
    engine = KupaDraftEngine(widget.repo,
        rng: o == null ? null : Random(o.bilgi.seed));
    o?.basla(_rakipHamle, onMacKapandi: _macKapandi);
    _sayacBaslat();
  }

  bool _kapanisIslendi = false;

  /// Rakip cekildi ya da mac sunucuda kapandi: hukmen kazanan biziz —
  /// oyunu durdur, seri akisina gec (kullanici kurali: rakip cihazda
  /// oyun DEVAM ETMEMELI).
  void _macKapandi() {
    if (!mounted || engine.bitti || _kapanisIslendi) return;
    _kapanisIslendi = true;
    sayac?.cancel();
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
    );
  }

  void _rakipHamle(Map<String, dynamic> h) {
    if (!mounted || engine.bitti) return;
    _hukmenTimer?.cancel();
    if (h['tip'] == 'cekildi') {
      _macKapandi();
      return;
    }
    if (h['tip'] != 'sec' && h['tip'] != 'sure') return;
    setState(() {
      if (h['tip'] == 'sec') {
        final idx = (h['idx'] as num).toInt();
        final o = widget.repo.oyuncular[idx];
        if (engine.sec(idx)) {
          sonAcilan = '${o.ad} — ${o.kupa} kupa';
        }
      } else if (h['tip'] == 'sure') {
        engine.sureDoldu();
        sonAcilan = 'Süre doldu — etap boş geçti';
      }
      aramaCtrl.clear();
      adaylar = [];
    });
    _sonrakiAdim();
  }

  void _sayacBaslat() {
    sayac?.cancel();
    kalanSn = turSn;
    sayac = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => kalanSn--);
      if (kalanSn <= 0) {
        t.cancel();
        if (!siraBende) {
          // Rakibin suresi rakibin istemcisinden bildirilir. 15 sn icinde
          // HICBIR hamle gelmezse rakip ayrilmis demektir → HUKMEN kazanan
          // biziz (kullanici kurali: oyundan/uygulamadan cikan maglup).
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && !siraBende) _macKapandi();
          });
          return;
        }
        widget.online?.gonder({'tip': 'sure'});
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
    if (a.neden != null || !siraBende) return;
    final o = widget.repo.oyuncular[a.idx];
    setState(() {
      if (engine.sec(a.idx)) {
        widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
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
    _hukmenTimer?.cancel();
    widget.online?.kapat();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secen = engine.bitti ? 0 : engine.simdiSecen;
    final acik = engine.bitti ? <String>[] : engine.acikMevkiler(secen);
    return PopScope(
      // ONLINE macta geri tusu sessiz kacis DEGIL: cekilme onayi acilir
      // (kullanici kurali: oyundan cikan maglup sayilir).
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
                      aktif: secen == 0,
                      oyunBitti: engine.bitti,
                      renk: GolrivaColors.p1,
                      child: _ustToplam(0, GolrivaColors.p1))),
              const SizedBox(width: 10),
              Expanded(
                  child: tarafVurgu(
                      aktif: secen == 1,
                      oyunBitti: engine.bitti,
                      renk: GolrivaColors.p2,
                      child: _ustToplam(1, GolrivaColors.p2))),
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
                    '${adlar[secen]} ${adlar[secen] == "Sen" ? "seçiyorsun" : "seçiyor"} · Açık: ${acik.map((z) => kupaSlotAd[z]).join(" · ")}',
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
                enabled: !engine.bitti && siraBende,
                onChanged: (v) => setState(() => adaylar = engine.adaylar(v)),
                decoration: InputDecoration(
                    hintText: siraBende
                        ? 'Futbolcu adı yaz… (en az 3 harf)'
                        : '${adlar[engine.bitti ? 0 : engine.simdiSecen]} oynuyor…',
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
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: tarafVurgu(
                      aktif: secen == 0,
                      oyunBitti: engine.bitti,
                      renk: GolrivaColors.p1,
                      child: _kadro(0, GolrivaColors.p1))),
              const SizedBox(width: 10),
              Expanded(
                  child: tarafVurgu(
                      aktif: secen == 1,
                      oyunBitti: engine.bitti,
                      renk: GolrivaColors.p2,
                      child: _kadro(1, GolrivaColors.p2))),
            ]),
          ],
        ),
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

  /// SAHA GORUNUMU (kullanici istegi, 30 Tem): kadro futbol sahasinda.
  Widget _kadro(int s, Color renk) {
    final bySlot = <String, List<int>>{'K': [], 'D': [], 'O': [], 'F': []};
    for (final p in engine.kadrolar[s]) {
      bySlot[p.poz]!.add(p.idx);
    }
    List<SahaSlot> sira(String z) => List.generate(kupaFormation[z]!, (k) {
          final list = bySlot[z]!;
          final idx = k < list.length ? list[k] : null;
          return SahaSlot(
              poz: z,
              pozAd: kupaSlotAd[z]!,
              ad: idx == null ? null : widget.repo.oyuncular[idx].ad,
              deger:
                  idx == null ? null : '${widget.repo.oyuncular[idx].kupa}');
        });
    return SahaKadro(
      baslik: adlar[s].toUpperCase(),
      sagBilgi: '${engine.kadrolar[s].length}/$kupaTurSayisi',
      renk: renk,
      siralar: [sira('F'), sira('O'), sira('D'), sira('K')],
    );
  }
}
