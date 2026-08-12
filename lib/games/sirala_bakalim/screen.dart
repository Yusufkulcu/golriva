import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repos.dart';
import '../../online/mac_kanali.dart';
import '../../online/oyun_yonlendirici.dart';
import '../../theme/golriva_theme.dart';
import '../../widgets/golriva_ui.dart';
import 'engine.dart';

/// SIRALA BAKALIM ekranı (Faz 2.18 · v2) — İKİ OYUNCU AYNI SORULARI SIRALAR.
/// Çevrimiçi: EŞ ZAMANLI — herkes kendi cihazında aynı 4'lüyü dizer, tur iki
/// taraf da gönderince açılır. Hot-seat: aynı soruyu önce O1 sonra O2 dizer.
/// Her doğru konum +1, kusursuz +1 bonus. 4 tur.
/// RESPONSIVE KURAL: kök yerleşim ListView.
class SiralaBakalimScreen extends StatefulWidget {
  final GolrivaRepos repos;
  final OnlineMacKanali? online; // null = hot-seat
  const SiralaBakalimScreen({super.key, required this.repos, this.online});

  @override
  State<SiralaBakalimScreen> createState() => _SiralaBakalimScreenState();
}

class _SiralaBakalimScreenState extends State<SiralaBakalimScreen> {
  late SiralaBakalimEngine engine;
  late final List<String> adlar;
  final List<int> secilen = []; // dokunma sırası (gösterim idx'leri)
  Timer? sayac;
  Timer? _hukmenTimer;
  int kalanSn = turSn;
  static const turSn = 30;
  bool _kapanisIslendi = false;
  bool _sonucAcik = false;

  /// Çevrimiçi: benim koltuk sabit. Hot-seat: sırada dolduran koltuk
  /// (önce göndermemiş olan — O1 sonra O2).
  int get benimSeat {
    final o = widget.online;
    if (o != null) return o.bilgi.benimSiram;
    return !engine.bitti && engine.gonderdi(0) ? 1 : 0;
  }

  bool get gonderdim => engine.bitti || engine.gonderdi(benimSeat);

  /// Son TAMAMLANMIŞ turun indeksi (açılış paneli) — yoksa -1.
  int get acilanTur => engine.bitti
      ? siralaTurSayisi - 1
      : engine.tur - 1; // tur 0'dayken -1 → panel yok

  @override
  void initState() {
    super.initState();
    final o = widget.online;
    adlar = o == null
        ? ['Oyuncu 1', 'Oyuncu 2']
        : (o.bilgi.benimSiram == 0
            ? ['Sen', o.bilgi.rakipAdi]
            : [o.bilgi.rakipAdi, 'Sen']);
    engine = SiralaBakalimEngine(widget.repos,
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
    if (tip != 'sirala' && tip != 'sure') return;
    final rakipSeat = 1 - widget.online!.bilgi.benimSiram;
    final hTur = (h['tur'] as num?)?.toInt() ?? engine.tur;
    if (hTur != engine.tur) return; // eski/uyumsuz tur — yoksay
    setState(() {
      if (tip == 'sirala') {
        final dizi =
            (h['dizi'] as List).map((x) => (x as num).toInt()).toList();
        engine.sirala(rakipSeat, dizi);
      } else {
        engine.sureDoldu(rakipSeat);
      }
    });
    _adimSonrasi();
  }

  void _adimSonrasi() {
    if (engine.bitti) {
      sayac?.cancel();
      _sonucGoster();
    } else {
      _sayacTazele();
    }
  }

  /// Tur ilerlediyse sayaç baştan; aynı turdaysa dokunma.
  int _sayacTuru = 0;
  void _sayacTazele() {
    if (_sayacTuru != engine.tur) {
      _sayacTuru = engine.tur;
      secilen.clear();
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
        if (widget.online != null && gonderdim) {
          // ben gönderdim, rakip gecikti — hamlesi kendi istemcisinden
          // gelir; gelmezse hükmen ağı devreye girer
          _hukmenTimer?.cancel();
          _hukmenTimer = Timer(const Duration(seconds: 15), () {
            if (mounted && !engine.bitti && gonderdim) _macKapandi();
          });
          return;
        }
        // süre doldu: göndermeyen taraf(lar) 0 puanla kapanır
        setState(() {
          if (widget.online != null) {
            widget.online!.gonder({'tip': 'sure', 'tur': engine.tur});
            engine.sureDoldu(benimSeat);
          } else {
            // hot-seat: kalan herkese 0
            if (!engine.gonderdi(0)) engine.sureDoldu(0);
            if (!engine.bitti && !engine.gonderdi(1)) engine.sureDoldu(1);
          }
          secilen.clear();
        });
        _adimSonrasi();
      }
    });
  }

  void _dokun(int i) {
    if (gonderdim || engine.bitti) return;
    setState(() {
      if (secilen.contains(i)) {
        secilen.remove(i); // geri al
      } else if (secilen.length < siralaOyuncuSayisi) {
        secilen.add(i);
      }
    });
  }

  void _onayla() {
    if (gonderdim || secilen.length != siralaOyuncuSayisi) return;
    final dizi = List.of(secilen);
    setState(() {
      if (widget.online != null) {
        widget.online!.gonder(
            {'tip': 'sirala', 'tur': engine.tur, 'dizi': dizi});
        engine.sirala(benimSeat, dizi);
      } else {
        engine.sirala(benimSeat, dizi); // hot-seat: sıradaki koltuk
      }
      secilen.clear();
    });
    _adimSonrasi();
    // hot-seat: sıradaki dolduran (ya da yeni tur) taze 30 sn alır
    if (widget.online == null && !engine.bitti) _sayacBaslat();
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
                      _skorKutu(0, GolrivaColors.p1),
                      _skorKutu(1, GolrivaColors.p2),
                    ]),
                const SizedBox(height: 8),
                Text(
                    k == null
                        ? 'Puanlar eşit — rövanş şart.'
                        : '${(engine.skor[0] - engine.skor[1]).abs()} puan farkla.',
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
                            engine = SiralaBakalimEngine(widget.repos);
                            secilen.clear();
                            _sayacTuru = 0;
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

  Widget _skorKutu(int s, Color renk) => Column(children: [
        Text(adlar[s].toUpperCase(),
            style: GoogleFonts.figtree(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1)),
        Text('${engine.skor[s]}',
            style: GoogleFonts.spaceGrotesk(
                color: GolrivaColors.goldHi,
                fontWeight: FontWeight.w700,
                fontSize: 26)),
        Text('puan',
            style: GoogleFonts.figtree(color: GolrivaColors.dim, fontSize: 10)),
      ]);

  @override
  void dispose() {
    sayac?.cancel();
    _hukmenTimer?.cancel();
    widget.online?.kapat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = engine.bitti ? null : engine.aktifTur;
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
            Text('SIRALA BAKALIM',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    letterSpacing: 2)),
            Text(
                engine.bitti
                    ? 'BİTTİ'
                    : 'TUR ${engine.tur + 1}/$siralaTurSayisi · SKOR ${engine.skor[0]}-${engine.skor[1]}',
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
                        aktif: !engine.bitti && !engine.gonderdi(0),
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p1,
                        child: _ustKutu(0, GolrivaColors.p1))),
                const SizedBox(width: 10),
                Expanded(
                    child: tarafVurgu(
                        aktif: !engine.bitti && !engine.gonderdi(1),
                        oyunBitti: engine.bitti,
                        renk: GolrivaColors.p2,
                        child: _ustKutu(1, GolrivaColors.p2))),
              ]),
              const SizedBox(height: 10),
              if (t != null) ...[
                // ── METRİK KARTI: büyük ad üstte, açıklama altta ──
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
                      child: Text(t.metrikAd,
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        widget.online != null
                            ? 'İKİNİZ DE AYNI 4\'LÜYÜ SIRALIYORSUNUZ — YÜKSEKTEN DÜŞÜĞE, HER DOĞRU KONUM +1, KUSURSUZ +1 BONUS'
                            : 'AYNI 4\'LÜYÜ ÖNCE ${adlar[0].toUpperCase()} SONRA ${adlar[1].toUpperCase()} SIRALAR — YÜKSEKTEN DÜŞÜĞE',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 9,
                            letterSpacing: 2,
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
                        kalanSn <= 6 ? GolrivaColors.bad : GolrivaColors.gold,
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
                const SizedBox(height: 10),
                if (!gonderdim) ...[
                  if (widget.online == null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Center(
                        child: Text('SIRALAYAN: ${adlar[benimSeat]}',
                            style: GoogleFonts.figtree(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: benimSeat == 0
                                    ? GolrivaColors.p1
                                    : GolrivaColors.p2)),
                      ),
                    ),
                  // ── OYUNCU KARTLARI (2x2) ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.4,
                    children: [
                      for (var i = 0; i < t.oyuncuAdlari.length; i++)
                        _oyuncuKart(t, i),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor:
                            secilen.length == siralaOyuncuSayisi
                                ? GolrivaColors.gold
                                : GolrivaColors.card2,
                        foregroundColor:
                            secilen.length == siralaOyuncuSayisi
                                ? const Color(0xFF231A04)
                                : GolrivaColors.dim2,
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    onPressed: secilen.length == siralaOyuncuSayisi
                        ? _onayla
                        : null,
                    child: Text(
                        secilen.length == siralaOyuncuSayisi
                            ? 'SIRALAMAYI ONAYLA'
                            : 'SIRAYLA DOKUN (${secilen.length}/$siralaOyuncuSayisi)',
                        style: GoogleFonts.bigShouldersDisplay(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 16)),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: kartDekor(r: 16),
                    child: Row(children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: GolrivaColors.gold, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            widget.online != null
                                ? 'Sıralaman gönderildi — rakibin bitirmesi bekleniyor. Değerler iki taraf da gönderince açılır.'
                                : 'Kayıt alındı.',
                            style: GoogleFonts.figtree(
                                fontSize: 12, color: GolrivaColors.dim)),
                      ),
                    ]),
                  ),
                ],
              ],
              // ── SON TAMAMLANAN TURUN AÇILIŞI ──
              if (acilanTur >= 0) ...[
                const SizedBox(height: 12),
                _acilisPaneli(acilanTur),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _acilisPaneli(int ti) {
    final t = engine.turlar[ti];
    final dogru = t.dogruSira();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: kartDekor(r: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: etiket('${t.metrikAd} — DOĞRU SIRALAMA')),
          Text(
              '${adlar[0]} +${engine.puanlar[ti][0] ?? 0} · '
              '${adlar[1]} +${engine.puanlar[ti][1] ?? 0}',
              style: GoogleFonts.figtree(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: GolrivaColors.goldHi)),
        ]),
        const SizedBox(height: 6),
        for (final (poz, gIdx) in dogru.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(children: [
              SizedBox(
                width: 20,
                child: Text('${poz + 1}.',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5, color: GolrivaColors.dim)),
              ),
              Expanded(
                child: Text(t.oyuncuAdlari[gIdx],
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                        fontSize: 12, color: GolrivaColors.ink)),
              ),
              Text('${siralaFmt(t.degerler[gIdx])} ${t.birim}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.goldHi)),
              for (final s in [0, 1]) ...[
                const SizedBox(width: 6),
                Icon(
                    (engine.verilenler[ti][s] ?? const []).length > poz &&
                            engine.verilenler[ti][s]![poz] == gIdx
                        ? Icons.check_circle
                        : Icons.cancel,
                    size: 13,
                    color: (engine.verilenler[ti][s] ?? const [])
                                    .length >
                                poz &&
                            engine.verilenler[ti][s]![poz] == gIdx
                        ? (s == 0 ? GolrivaColors.p1 : GolrivaColors.p2)
                        : GolrivaColors.dim2),
              ],
            ]),
          ),
      ]),
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
          Text('${engine.skor[s]}',
              style: GoogleFonts.spaceGrotesk(
                  color: GolrivaColors.goldHi,
                  fontWeight: FontWeight.w700,
                  fontSize: 22)),
          Text(
              engine.bitti
                  ? 'puan'
                  : engine.gonderdi(s)
                      ? 'GÖNDERDİ'
                      : 'sıralıyor…',
              style: GoogleFonts.figtree(
                  color: engine.gonderdi(s) && !engine.bitti
                      ? GolrivaColors.ok
                      : GolrivaColors.dim,
                  fontSize: 9)),
        ]),
      );

  Widget _oyuncuKart(SiralaTur t, int i) {
    final sira = secilen.indexOf(i);
    final secili = sira >= 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _dokun(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: secili ? const Color(0x22D4AF37) : GolrivaColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: secili ? GolrivaColors.gold : GolrivaColors.edge2,
              width: secili ? 1.6 : 1),
        ),
        child: Row(children: [
          if (secili)
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 8),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: GolrivaColors.gold),
              child: Text('${sira + 1}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF231A04))),
            ),
          Expanded(
            child: Text(t.oyuncuAdlari[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.ink)),
          ),
        ]),
      ),
    );
  }
}
