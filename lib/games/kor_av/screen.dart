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

/// Kor av ekran yapilandirmasi — Bonservis Avi / Sari Kart Avi.
class KorAvConfig {
  final String baslik; // "BONSERVİS AVI"
  final String hedefEtiket; // "TOPLAM BONSERVİS HEDEFİ"
  final String birim; // "M€" / "sarı kart"
  const KorAvConfig(
      {required this.baslik, required this.hedefEtiket, required this.birim});
}

const bonservisConfig = KorAvConfig(
    baslik: 'BONSERVİS AVI',
    hedefEtiket: 'TOPLAM BONSERVİS HEDEFİ',
    birim: 'M€');
const sariKartConfig = KorAvConfig(
    baslik: 'SARI KART AVI',
    hedefEtiket: 'TOPLAM SARI KART HEDEFİ',
    birim: 'sarı kart');

/// KOR AV ekrani — kor hedef avi (hot-seat), kademeli skor acilisiyla.
/// RESPONSIVE KURAL: kok yerlesim ListView.
class KorAvScreen extends StatefulWidget {
  final KorAvRepository repo;
  final KorAvConfig config;
  final OnlineMacKanali? online; // null = hot-seat
  const KorAvScreen(
      {super.key, required this.repo, required this.config, this.online});

  @override
  State<KorAvScreen> createState() => _KorAvScreenState();
}

class _KorAvScreenState extends State<KorAvScreen> {
  late KorAvEngine engine;
  late final List<String> adlar;
  final aramaCtrl = TextEditingController();
  List<KorAvAday> adaylar = [];
  String? uyari;
  Timer? sayac;
  Timer? _hukmenTimer; // rakip kayboldu mu? (hukmen)
  int kalanSn = 20;
  static const turSn = 20;

  bool acilisModu = false;
  final Set<(int, int)> acikSet = {};
  (int, int)? sonAcilanHucre;
  Timer? acilisTimer;

  bool get siraBende =>
      widget.online == null || engine.sira == widget.online!.bilgi.benimSiram;

  /// Hak bitince sıra aynı oyuncuda kalır (motor kuralı) — bunu açıkça
  /// söylemezsek "sıra iki kere geçti" diye hata sanılıyor.
  String? get _siraNotu {
    if (widget.online == null || engine.bitti) return null;
    if (engine.kalanHak(1 - engine.sira) <= 0) {
      return siraBende
          ? 'Rakibin seçim hakkı bitti — kalan seçimlerin hepsi sende.'
          : 'Seçim hakkın bitti — rakip kalan seçimlerini yapıyor.';
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
    engine =
        KorAvEngine(widget.repo, rng: o == null ? null : Random(o.bilgi.seed));
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
        if (engine.sec((h['idx'] as num).toInt())) uyari = null;
      } else if (h['tip'] == 'sure') {
        uyari = '${adlar[engine.sira]} — süre doldu, hak yandı (0 sayılır)';
        engine.sureDoldu();
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
          uyari = '${adlar[engine.sira]} — süre doldu, hak yandı (0 sayılır)';
          engine.sureDoldu();
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
      _acilisiBaslat();
    } else {
      _sayacBaslat();
    }
  }

  void _sec(KorAvAday a) {
    if (a.neden != null || !siraBende) return;
    setState(() {
      if (engine.sec(a.idx)) {
        widget.online?.gonder({'tip': 'sec', 'idx': a.idx});
        uyari = null;
        aramaCtrl.clear();
        adaylar = [];
      }
    });
    _sonrakiAdim();
  }

  void _acilisiBaslat() {
    setState(() => acilisModu = true);
    final sira = engine.acilisSirasi();
    var k = 0;
    void adim() {
      if (!mounted) return;
      if (k >= sira.length) {
        _sonucGoster();
        return;
      }
      setState(() {
        sonAcilanHucre = sira[k];
        acikSet.add(sira[k]);
        k++;
      });
      acilisTimer = Timer(const Duration(milliseconds: 1000), adim);
    }

    acilisTimer = Timer(const Duration(milliseconds: 700), adim);
  }

  void _acilisiAtla() {
    if (!acilisModu) return;
    acilisTimer?.cancel();
    _sonucGoster();
  }

  void _sonucGoster() {
    if (!mounted) return;
    acilisTimer?.cancel();
    setState(() {
      for (var s = 0; s < 2; s++) {
        for (var r = 0; r < engine.secimler[s].length; r++) {
          acikSet.add((s, r));
        }
      }
      sonAcilanHucre = null;
    });
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
                  'Hedef ${engine.hedef} ${widget.config.birim}'
                  '${k == null ? " — ikiniz de eşit uzaktasınız." : " — ${adlar[k]} ${korAvFmt(engine.fark(k))} farkla daha yakın."}',
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
                        engine = KorAvEngine(widget.repo);
                        acilisModu = false;
                        acikSet.clear();
                        sonAcilanHucre = null;
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
    );
  }

  Widget _toplamKutu(int s, Color renk) => Column(children: [
        Text(adlar[s].toUpperCase(),
            style: GoogleFonts.figtree(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1)),
        Text(korAvFmt(engine.toplam(s)),
            style: GoogleFonts.spaceGrotesk(
                color: GolrivaColors.goldHi,
                fontWeight: FontWeight.w700,
                fontSize: 26)),
        Text('fark ${korAvFmt(engine.fark(s))}',
            style: GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 10)),
      ]);

  @override
  void dispose() {
    sayac?.cancel();
    _hukmenTimer?.cancel();
    acilisTimer?.cancel();
    widget.online?.kapat();
    aramaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secen = engine.bitti ? 0 : engine.sira;
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
          Text(widget.config.baslik,
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text(
              engine.bitti
                  ? (acilisModu ? 'SKORLAR AÇILIYOR…' : 'BİTTİ')
                  : 'KÖR SIRALAMA · ${engine.kadroN} FUTBOLCU',
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: acilisModu ? _acilisiAtla : null,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              if (widget.online != null && !engine.bitti) ...[
                const SizedBox(height: 10),
                SiraSeridi(
                    siraBende: siraBende,
                    rakipAdi: widget.online!.bilgi.rakipAdi,
                    notu: _siraNotu),
              ],
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
                  Text(widget.config.hedefEtiket,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: GolrivaColors.dim,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${engine.hedef} ${widget.config.birim}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: GolrivaColors.goldHi)),
                  ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
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
                      '${adlar[secen]} ${adlar[secen] == "Sen" ? "yazıyorsun" : "yazıyor"} · kalan hak: ${engine.kalanHak(secen)}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              secen == 0 ? GolrivaColors.p1 : GolrivaColors.p2),
                    ),
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
                  enabled: !engine.bitti && siraBende,
                  onChanged: (v) =>
                      setState(() => adaylar = engine.adaylar(v)),
                  decoration: InputDecoration(
                      hintText: siraBende
                          ? 'Futbolcu adı yaz… (en az 3 harf)'
                          : '${adlar[engine.bitti ? 0 : engine.sira]} oynuyor…',
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
              if (acilisModu)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Dokun → hepsini aç',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 11, color: GolrivaColors.dim)),
                ),
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
    ),
    );
  }

  Widget _adayRow(KorAvAday a) {
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
                // deger META'DA YOK — kor mekanik!
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

  Widget _kadro(int s, Color renk) {
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
          Text('${engine.secimler[s].length}/${engine.kadroN}',
              style: GoogleFonts.spaceGrotesk(
                  color: GolrivaColors.dim, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        for (var r = 0; r < engine.kadroN; r++) _satir(s, r),
      ]),
    );
  }

  Widget _satir(int s, int r) {
    final dolu = r < engine.secimler[s].length;
    final acik = acikSet.contains((s, r));
    final yeni = sonAcilanHucre == (s, r);
    final i = dolu ? engine.secimler[s][r] : -1;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: yeni
            ? GolrivaColors.gold.withValues(alpha: .18)
            : GolrivaColors.card2,
        borderRadius: BorderRadius.circular(10),
        border: yeni ? Border.all(color: GolrivaColors.gold) : null,
      ),
      child: Row(children: [
        Expanded(
          child: Text(dolu ? widget.repo.oyuncular[i].ad : '—',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: dolu ? GolrivaColors.ink : GolrivaColors.dim2)),
        ),
        const SizedBox(width: 6),
        Text(dolu ? (acik ? korAvFmt(engine.deger(i)) : '?') : '',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: acik ? GolrivaColors.goldHi : GolrivaColors.dim)),
      ]),
    );
  }
}
