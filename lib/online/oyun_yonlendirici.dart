import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../games/en_genc_kadro/screen.dart';
import '../games/en_kisa_kadro/screen.dart';
import '../games/hedefi_tuttur/screen.dart';
import '../games/kor_av/screen.dart';
import '../games/kupa_drafti/screen.dart';
import '../games/serbest_kadro/engine.dart';
import '../games/serbest_kadro/screen.dart';
import '../theme/golriva_theme.dart';
import 'mac_kanali.dart';

const onlineOyunAdlari = {
  'en_kisa_kadro': 'EN KISA KADRO',
  'kupa_drafti': 'KUPA DRAFTI',
  'en_genc_kadro': 'EN GENÇ KADRO',
  'bayrak_yarisi': 'BAYRAK YARIŞI',
  'hedefi_tuttur': 'HEDEFİ TUTTUR',
  'bonservis_avi': 'BONSERVİS AVI',
  'sari_kart_avi': 'SARI KART AVI',
  'mac_rekortmenleri': 'MAÇ REKORTMENLERİ',
  'milli_gol_krallari': 'MİLLİ GOL KRALLARI',
  'kariyer_ikizi': 'KARİYER İKİZİ',
};

/// oyun_kodu → cevrimici oyun akisi. Once HAZIRLIK ekrani gelir:
/// iki taraf da HAZIR'a basinca 3-2-1 ile mac AYNI ANDA baslar
/// (kullanici kurali: sayaclar es zamanli olmali).
Widget onlineOyunEkrani(GolrivaRepos repos, OnlineMacBilgi bilgi) {
  final kanal = OnlineMacKanali(bilgi);
  kanal.sonrakiEkranKur = (b) => onlineOyunEkrani(repos, b);
  return OnlineHazirlikEkrani(
      kanal: kanal, oyunEkraniKur: () => _oyunEkrani(repos, kanal));
}

Widget _oyunEkrani(GolrivaRepos repos, OnlineMacKanali kanal) {
  final bilgi = kanal.bilgi;
  switch (bilgi.oyunKodu) {
    case 'en_kisa_kadro':
      return EnKisaKadroScreen(repo: repos.boy, online: kanal);
    case 'en_genc_kadro':
      return EnGencKadroScreen(repo: repos.genc, online: kanal);
    case 'kupa_drafti':
      return KupaDraftiScreen(repo: repos.kupa, online: kanal);
    case 'hedefi_tuttur':
      return HedefiTutturScreen(repo: repos.hedef, online: kanal);
    case 'bonservis_avi':
      return KorAvScreen(
          repo: repos.fee, config: bonservisConfig, online: kanal);
    case 'sari_kart_avi':
      return KorAvScreen(
          repo: repos.card, config: sariKartConfig, online: kanal);
    case 'mac_rekortmenleri':
      return SerbestKadroScreen(
          repo: repos.mac, config: macConfig, online: kanal);
    case 'milli_gol_krallari':
      return SerbestKadroScreen(
          repo: repos.milligol, config: milligolConfig, online: kanal);
    default:
      return Scaffold(
          body: Center(
              child: Text('Bilinmeyen oyun: ${bilgi.oyunKodu}',
                  style: GoogleFonts.figtree(color: GolrivaColors.bad))));
  }
}

/// Cekilme akisi: onay → rakibi kazanan bildir → seri akisi dialogu.
Future<void> cekilAkisi(BuildContext context, OnlineMacKanali kanal) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: GolrivaColors.card,
      title: Text('Maçtan çekil?',
          style: GoogleFonts.bigShouldersDisplay(
              fontWeight: FontWeight.w900, color: GolrivaColors.ink)),
      content: Text('Bu maç hükmen rakibin olur.',
          style: GoogleFonts.figtree(color: GolrivaColors.dim)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('VAZGEÇ')),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ÇEKİL',
                style: TextStyle(color: GolrivaColors.bad))),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  // Rakibin ekrani ANINDA ogrensin diye kanala cekilme sinyali birak
  // (kanal ayrica mac durumunu da yoklar — cifte emniyet).
  kanal.gonder({'tip': 'cekildi'});
  final rakipSeat = kanal.bilgi.benimSiram == 0 ? 1 : 0;
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
          Text('MAÇTAN ÇEKİLDİN',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: GolrivaColors.bad,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          OnlineSonucButonlari(kanal: kanal, kazananSeat: rakipSeat),
        ]),
      ),
    ),
  );
}

/// HAZIRLIK EKRANI: iki taraf da HAZIR'a basana kadar mac baslamaz;
/// ikisi de hazir olunca 3-2-1 geri sayimla oyun ekranina gecilir —
/// boylece iki cihazin sayaci da ayni anda calismaya baslar.
class OnlineHazirlikEkrani extends StatefulWidget {
  final OnlineMacKanali kanal;
  final Widget Function() oyunEkraniKur;
  const OnlineHazirlikEkrani(
      {super.key, required this.kanal, required this.oyunEkraniKur});

  @override
  State<OnlineHazirlikEkrani> createState() => _OnlineHazirlikEkraniState();
}

class _OnlineHazirlikEkraniState extends State<OnlineHazirlikEkrani> {
  bool benHazir = false;
  bool rakipHazir = false;
  bool rakipCekildi = false;
  bool hedefAraniyor = false;
  DateTime? baslangicHedefi; // yerel saate cevrilmis SUNUCU hedefi
  int? geriSayim;
  Timer? sayimTimer;

  @override
  void initState() {
    super.initState();
    widget.kanal.basla(_hamle, onMacKapandi: _kapandi);
  }

  void _hamle(Map<String, dynamic> h) {
    if (!mounted) return;
    if (h['tip'] == 'hazir') {
      // rakibin HAZIR durumu ANINDA gosterilir (kullanici istegi)
      setState(() => rakipHazir = true);
      _kontrol();
    } else if (h['tip'] == 'cekildi') {
      _kapandi();
    }
  }

  void _kapandi() {
    if (!mounted || rakipCekildi || baslangicHedefi != null) return;
    setState(() => rakipCekildi = true);
  }

  void _hazirBas() {
    if (benHazir) return;
    setState(() => benHazir = true);
    widget.kanal.gonder({'tip': 'hazir'});
    _kontrol();
  }

  /// Iki taraf da hazirsa SUNUCU-SENKRON hedefi bul: baslangic ani
  /// = ikinci hazir'in sunucu zamani + 4 sn. Iki cihaz da ayni mutlak
  /// ani hedefler → geri sayim es zamanli biter (kullanici kurali).
  void _kontrol() {
    if (!benHazir || !rakipHazir || hedefAraniyor) return;
    hedefAraniyor = true;
    _hedefiBul();
  }

  Future<void> _hedefiBul() async {
    for (var deneme = 0; deneme < 12 && mounted; deneme++) {
      try {
        final kalan = await widget.kanal.hazirGeriSayimKalan();
        if (kalan != null) {
          _sayimiBaslat(kalan.inMilliseconds < 300
              ? const Duration(milliseconds: 300)
              : kalan);
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
    }
    // sunucu saati alinamadiysa yerel 3 sn ile yine de basla
    if (mounted) _sayimiBaslat(const Duration(seconds: 3));
  }

  void _sayimiBaslat(Duration kalan) {
    if (!mounted || baslangicHedefi != null) return;
    setState(() => baslangicHedefi = DateTime.now().add(kalan));
    _sayimTikla();
    sayimTimer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => _sayimTikla());
  }

  void _sayimTikla() {
    if (!mounted || baslangicHedefi == null) return;
    final kalanMs =
        baslangicHedefi!.difference(DateTime.now()).inMilliseconds;
    if (kalanMs <= 0) {
      sayimTimer?.cancel();
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.oyunEkraniKur()));
    } else {
      final s = (kalanMs / 1000).ceil();
      if (s != geriSayim) setState(() => geriSayim = s);
    }
  }

  @override
  void dispose() {
    sayimTimer?.cancel();
    // DIKKAT: kanal.kapat() YOK — kanal oyun ekranina devrediliyor.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.kanal.bilgi;
    return PopScope(
      canPop: false, // geri tusu ile sessiz kacis yok — VAZGEÇ hukmen sayilir
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text('MAÇ HAZIRLIĞI',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22D4AF37), GolrivaColors.card]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GolrivaColors.edge),
                ),
                child: Column(children: [
                  Text('RULETİN SEÇTİĞİ OYUN',
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 2.5,
                          color: GolrivaColors.dim,
                          fontWeight: FontWeight.w700)),
                  Text(onlineOyunAdlari[b.oyunKodu] ?? b.oyunKodu,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text('rakip: ${b.rakipAdi} · ${b.mod == "bo3" ? "3 maçlık seri" : "tek maç"}',
                      style: GoogleFonts.figtree(
                          fontSize: 12, color: GolrivaColors.p2)),
                  const SizedBox(height: 18),
                  if (rakipCekildi) ...[
                    Text('RAKİP ÇEKİLDİ',
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: GolrivaColors.goldHi,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    OnlineSonucButonlari(
                        kanal: widget.kanal, kazananSeat: b.benimSiram),
                  ] else ...[
                    // HAZIR DURUM GOSTERGESI (kullanici istegi): iki kisi
                    // figuru — hazir olan takim renginde dolar.
                    Row(children: [
                      Expanded(
                          child: _HazirKutu(
                              ad: 'SEN',
                              hazir: benHazir,
                              renk: GolrivaColors.p1)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _HazirKutu(
                              ad: b.rakipAdi.toUpperCase(),
                              hazir: rakipHazir,
                              renk: GolrivaColors.p2)),
                    ]),
                    const SizedBox(height: 16),
                  ],
                  if (!rakipCekildi && baslangicHedefi != null) ...[
                    Text('${geriSayim ?? ""}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 64,
                            fontWeight: FontWeight.w700,
                            color: GolrivaColors.goldHi)),
                    Text('MAÇ BAŞLIYOR',
                        style: GoogleFonts.figtree(
                            fontSize: 11,
                            letterSpacing: 2,
                            color: GolrivaColors.dim,
                            fontWeight: FontWeight.w700)),
                  ] else if (!rakipCekildi) ...[
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor:
                              benHazir ? GolrivaColors.card2 : GolrivaColors.gold,
                          foregroundColor: benHazir
                              ? GolrivaColors.dim
                              : const Color(0xFF231A04),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 14)),
                      onPressed: benHazir ? null : _hazirBas,
                      child: Text(benHazir ? 'HAZIRSIN' : 'HAZIR',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontSize: 19)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                        benHazir
                            ? '${b.rakipAdi} bekleniyor…'
                            : 'İki taraf da HAZIR deyince maç 3-2-1 ile aynı anda başlar.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 11.5, color: GolrivaColors.dim)),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: GolrivaColors.dim,
                          side: const BorderSide(color: GolrivaColors.edge2)),
                      onPressed: () => cekilAkisi(context, widget.kanal),
                      child: Text('VAZGEÇ (HÜKMEN)',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hazir durum kutusu: kisi figuru (vektorel cizim — GOLRIVA kurali) +
/// ad + HAZIR/bekleniyor durumu. Hazir olunca takim rengine boyanir.
class _HazirKutu extends StatelessWidget {
  final String ad;
  final bool hazir;
  final Color renk;
  const _HazirKutu({required this.ad, required this.hazir, required this.renk});

  @override
  Widget build(BuildContext context) {
    final aktifRenk = hazir ? renk : GolrivaColors.dim2;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: hazir ? renk.withValues(alpha: .10) : GolrivaColors.card2,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: hazir ? renk : GolrivaColors.edge2, width: 1.5),
      ),
      child: Column(children: [
        CustomPaint(
            size: const Size(34, 34), painter: _KisiFiguru(aktifRenk, hazir)),
        const SizedBox(height: 6),
        Text(ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.figtree(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
                color: hazir ? renk : GolrivaColors.dim)),
        const SizedBox(height: 2),
        Text(hazir ? 'HAZIR' : 'bekleniyor…',
            style: GoogleFonts.figtree(
                fontSize: 10,
                fontWeight: hazir ? FontWeight.w800 : FontWeight.w500,
                fontStyle: hazir ? FontStyle.normal : FontStyle.italic,
                letterSpacing: hazir ? 1.5 : 0,
                color: hazir ? GolrivaColors.ok : GolrivaColors.dim2)),
      ]),
    );
  }
}

/// Basit kisi silueti: kafa + omuz yayi (stroke 1.8, yuvarlak uc).
class _KisiFiguru extends CustomPainter {
  final Color renk;
  final bool dolu;
  _KisiFiguru(this.renk, this.dolu);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = renk
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = dolu ? PaintingStyle.fill : PaintingStyle.stroke;
    final cizgi = Paint()
      ..color = renk
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // kafa
    canvas.drawCircle(
        Offset(size.width / 2, size.height * .30), size.width * .17, p);
    // omuzlar / govde yayi
    final govde = Rect.fromLTRB(size.width * .16, size.height * .52,
        size.width * .84, size.height * 1.30);
    if (dolu) {
      canvas.drawArc(govde, 3.14159, 3.14159, true, p);
    } else {
      canvas.drawArc(govde, 3.14159, 3.14159, false, cizgi);
    }
  }

  @override
  bool shouldRepaint(covariant _KisiFiguru old) =>
      old.renk != renk || old.dolu != dolu;
}

/// Mac sonu ONLINE butonlari: sonucu sunucuya bildirir, seri durumuna gore
/// "SONRAKİ MAÇ" (bo3 devam) ya da seri sonucu + "LOBİYE DÖN" gosterir.
/// Iki istemci de bildirir; sunucu ilk raporu isler (cift islem imkansiz).
class OnlineSonucButonlari extends StatefulWidget {
  final OnlineMacKanali kanal;
  final int? kazananSeat; // 0/1/null(berabere)
  const OnlineSonucButonlari(
      {super.key, required this.kanal, required this.kazananSeat});

  @override
  State<OnlineSonucButonlari> createState() => _OnlineSonucButonlariState();
}

class _OnlineSonucButonlariState extends State<OnlineSonucButonlari> {
  OnlineSeriDurumu? durum;
  String? hata;

  @override
  void initState() {
    super.initState();
    widget.kanal.kapat(); // hamle yoklamasi biter
    widget.kanal.sonucBildir(widget.kazananSeat).then(
        (d) => mounted ? setState(() => durum = d) : null, onError: (e) {
      if (mounted) setState(() => hata = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hata != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Sonuç işlenemedi: $hata',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
                fontSize: 12, color: GolrivaColors.bad)),
        const SizedBox(height: 8),
        _lobiButonu(context),
      ]);
    }
    final d = durum;
    if (d == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: GolrivaColors.gold, strokeWidth: 2.5)),
        const SizedBox(height: 6),
        Text('Sonuç sunucuya işleniyor…',
            style: GoogleFonts.figtree(
                fontSize: 11, color: GolrivaColors.dim)),
      ]);
    }
    final b = widget.kanal.bilgi;
    final skorum = b.benimSiram == 0 ? d.skor1 : d.skor2;
    final skorRakip = b.benimSiram == 0 ? d.skor2 : d.skor1;
    if (!d.seriBitti && d.sonrakiMac != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('SERİ $skorum - $skorRakip · devam ediyor',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.goldHi)),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: GolrivaColors.gold,
              foregroundColor: const Color(0xFF231A04),
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
          onPressed: () {
            final nav = Navigator.of(context);
            final ekran = widget.kanal.sonrakiEkranKur!(d.sonrakiMac!);
            nav.pop(); // dialogu kapat
            nav.pushReplacement(MaterialPageRoute(builder: (_) => ekran));
          },
          child: Text('SONRAKİ MAÇ',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        ),
      ]);
    }
    final benimUid = b.seatUid(b.benimSiram);
    final mesaj = d.kazananUid == null
        ? 'SERİ BERABERE ($skorum - $skorRakip) — girişler iade edildi'
        : d.kazananUid == benimUid
            ? 'SERİYİ KAZANDIN ($skorum - $skorRakip) — ödül cüzdanında!'
            : 'Seriyi ${b.rakipAdi} aldı ($skorum - $skorRakip)';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(mesaj,
          textAlign: TextAlign.center,
          style: GoogleFonts.figtree(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: d.kazananUid == benimUid
                  ? GolrivaColors.ok
                  : GolrivaColors.dim)),
      const SizedBox(height: 10),
      _lobiButonu(context),
    ]);
  }

  Widget _lobiButonu(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: GolrivaColors.gold,
            foregroundColor: const Color(0xFF231A04),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
        onPressed: () =>
            Navigator.of(context).popUntil((r) => r.isFirst),
        child: Text('LOBİYE DÖN',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
      );
}
