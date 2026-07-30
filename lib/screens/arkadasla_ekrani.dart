import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../games/bayrak_yarisi/screen.dart';
import '../games/en_genc_kadro/screen.dart';
import '../games/en_kisa_kadro/screen.dart';
import '../games/hedefi_tuttur/screen.dart';
import '../games/kariyer_ikizi/screen.dart';
import '../games/kor_av/screen.dart';
import '../games/kupa_drafti/screen.dart';
import '../games/serbest_kadro/engine.dart';
import '../games/serbest_kadro/screen.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// EKRAN 12 · ARKADAŞLA OYNA — dostluk maci: oyun secimi BURADA serbest
/// (ranked'da rulet zorunlu, tasarim kurali). Su an ayni cihazda hot-seat;
/// davet koduyla uzaktan dostluk maci Faz 2.4'te.
class ArkadaslaEkrani extends StatelessWidget {
  final GolrivaRepos repos;
  const ArkadaslaEkrani({super.key, required this.repos});

  List<(String, String, String, Widget Function())> _oyunlar() => [
        ('kupa_drafti', 'KUPA DRAFTI', 'Draft · 6 tur',
            () => KupaDraftiScreen(repo: repos.kupa)),
        ('en_kisa_kadro', 'EN KISA KADRO', 'Draft · boy',
            () => EnKisaKadroScreen(repo: repos.boy)),
        ('en_genc_kadro', 'EN GENÇ KADRO', 'Draft · yaş',
            () => EnGencKadroScreen(repo: repos.genc)),
        ('bayrak_yarisi', 'BAYRAK YARIŞI', 'Refleks',
            () => BayrakYarisiScreen(repo: repos.boy)),
        ('hedefi_tuttur', 'HEDEFİ TUTTUR', 'Kör av',
            () => HedefiTutturScreen(repo: repos.hedef)),
        ('bonservis_avi', 'BONSERVİS AVI', 'Kör av',
            () => KorAvScreen(repo: repos.fee, config: bonservisConfig)),
        ('sari_kart_avi', 'SARI KART AVI', 'Kör av',
            () => KorAvScreen(repo: repos.card, config: sariKartConfig)),
        ('mac_rekortmenleri', 'MAÇ REKORTMENLERİ', 'Serbest kadro',
            () => SerbestKadroScreen(repo: repos.mac, config: macConfig)),
        ('milli_gol_krallari', 'MİLLİ GOL KRALLARI', 'Serbest kadro',
            () => SerbestKadroScreen(
                repo: repos.milligol, config: milligolConfig)),
        ('kariyer_ikizi', 'KARİYER İKİZİ', 'Soru',
            () => KariyerIkiziScreen(repo: repos.ikiz)),
      ];

  void _ac(BuildContext context, Widget Function() ekran) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ekran()));

  @override
  Widget build(BuildContext context) {
    final oyunlar = _oyunlar();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text('ARKADAŞLA OYNA',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text('BİRİMSİZ · ELO\'SUZ · KEYİF MAÇI',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 9.5,
                  color: GolrivaColors.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ]),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          children: [
            // davet kodu — uzaktan dostluk maci Faz 2.4'te
            Opacity(
              opacity: .55,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: gKartDekor(),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          etiket('DAVET KODU · YAKINDA'),
                          Text('GLR-····',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 4,
                                  color: GolrivaColors.goldHi)),
                        ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        gradient: GolrivaColors.goldGradient,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text('KOPYALA',
                        style: GoogleFonts.figtree(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF231A04))),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('OYUN SEÇ',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: etiket('· YA DA RULETE BIRAK'),
              ),
            ]),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 2.9,
              children: [
                // RULET: rastgele oyun ac
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      _ac(context, oyunlar[Random().nextInt(oyunlar.length)].$4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: gKartDekor(r: 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            gIkon('rulet', 13, GolrivaColors.goldHi),
                            const SizedBox(width: 4),
                            Text('RULET',
                                style: GoogleFonts.bigShouldersDisplay(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5,
                                    color: GolrivaColors.goldHi)),
                          ]),
                          Text('Rastgele seçsin',
                              style: GoogleFonts.figtree(
                                  fontSize: 9, color: GolrivaColors.dim)),
                        ]),
                  ),
                ),
                for (final o in oyunlar)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _ac(context, o.$4),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: kartDekor(r: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(o.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.bigShouldersDisplay(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .5)),
                            Text(o.$3,
                                style: GoogleFonts.figtree(
                                    fontSize: 9, color: GolrivaColors.dim)),
                          ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
                'Şimdilik aynı cihazda sırayla oynanır (hot-seat). '
                'Davet koduyla uzaktan dostluk maçı yakında.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 10.5, color: GolrivaColors.dim2)),
          ],
        ),
      ),
    );
  }
}
