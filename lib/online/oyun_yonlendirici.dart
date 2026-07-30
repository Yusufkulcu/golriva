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

/// oyun_kodu → cevrimici oyun ekrani. Kanala "sonraki mac" kurucusunu da
/// baglar (bo3'te ayni seri icinde zincirleme gecis).
Widget onlineOyunEkrani(GolrivaRepos repos, OnlineMacBilgi bilgi) {
  final kanal = OnlineMacKanali(bilgi);
  kanal.sonrakiEkranKur = (b) => onlineOyunEkrani(repos, b);
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
