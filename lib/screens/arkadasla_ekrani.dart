import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../online/davet_ekrani.dart';
import '../online/supabase_ayar.dart';
import '../games/bayrak_yarisi/screen.dart';
import '../games/en_genc_kadro/screen.dart';
import '../games/en_kisa_kadro/screen.dart';
import '../games/hedefi_tuttur/screen.dart';
import '../games/kariyer_ikizi/screen.dart';
import '../games/kor_av/screen.dart';
import '../games/kupa_drafti/screen.dart';
import '../games/serbest_kadro/engine.dart';
import '../games/serbest_kadro/screen.dart';
import '../games/veto_drafti/screen.dart';
import '../games/yirmibir/screen.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'arkadaslar_ekrani.dart';

/// EKRAN 12 · ARKADAŞLA OYNA — dostluk maci: oyun secimi BURADA serbest
/// (ranked'da rulet zorunlu, tasarim kurali). Iki yol:
/// UZAKTAN (davet koduyla, Riva'siz/Elo'suz) ya da AYNI CIHAZDA (hot-seat).
class ArkadaslaEkrani extends StatelessWidget {
  final GolrivaRepos repos;
  const ArkadaslaEkrani({super.key, required this.repos});

  List<(String, String, String, Widget Function())> _oyunlar() => [
        ('kupa_drafti', 'KUPA DRAFTI', 'Draft · 6 tur',
            () => KupaDraftiScreen(repo: repos.kupa)),
        ('en_kisa_kadro', 'EN KISA KADROYU KUR', 'Draft · boy',
            () => EnKisaKadroScreen(repo: repos.boy)),
        ('en_genc_kadro', 'EN GENÇ KADROYU KUR', 'Draft · yaş',
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
        ('milli_gol_krallari', 'MİLLİ TAKIM GOL KRALLARI', 'Serbest kadro',
            () => SerbestKadroScreen(
                repo: repos.milligol, config: milligolConfig)),
        ('kariyer_ikizi', 'KARİYER İKİZİ', 'Soru',
            () => KariyerIkiziScreen(repo: repos.ikiz)),
        ('bonservis_21', 'BONSERVİS 21\'İ', 'Kör av · blackjack',
            () => YirmibirScreen(repo: repos.fee)),
        ('veto_drafti', 'VETO DRAFTI', 'Draft · veto',
            () => VetoDraftiScreen(repo: repos.kupa)),
      ];

  void _ac(BuildContext context, Widget Function() ekran) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ekran()));

  /// Davet akisi cevrimici ister; degilse kibarca soyle ve false don.
  bool _cevrimiciGerekli(BuildContext context) {
    if (SupabaseAyar.yapilandirildi) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Uzaktan oynamak için çevrimiçi yapılandırma gerekli '
            '(README_SUPABASE.md). Aynı cihazda oynamaya devam edebilirsin.')));
    return false;
  }

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
            // ── UZAKTAN OYNA: davet kodu (dostluk — Riva'siz/Elo'suz) ──
            Container(
              padding: const EdgeInsets.all(13),
              decoration: gKartDekor(),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    etiket('UZAKTAN OYNA · DAVET KODUYLA'),
                    const SizedBox(height: 3),
                    Text('İki telefon, tek kod — Riva ve Elo işlemez.',
                        style: GoogleFonts.figtree(
                            fontSize: 10.5, color: GolrivaColors.dim)),
                    const SizedBox(height: 9),
                    Row(children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _cevrimiciGerekli(context)
                              ? Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => DavetKurEkrani(
                                          repos: repos)))
                              : null,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                gradient: GolrivaColors.goldGradient,
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('DAVET KUR',
                                style: GoogleFonts.bigShouldersDisplay(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: const Color(0xFF231A04))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _cevrimiciGerekli(context)
                              ? davetKatilDialog(context, repos)
                              : null,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: kartDekor(r: 12).copyWith(
                                border:
                                    Border.all(color: GolrivaColors.edge)),
                            child: Text('KODLA KATIL',
                                style: GoogleFonts.bigShouldersDisplay(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: GolrivaColors.goldHi)),
                          ),
                        ),
                      ),
                    ]),
                  ]),
            ),
            const SizedBox(height: 9),
            // arkadas listesi kisayolu
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ArkadaslarEkrani(repos: repos))),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 10),
                decoration: kartDekor(r: 14),
                child: Row(children: [
                  gIkon('nav_profil', 16, GolrivaColors.dim),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('Arkadaşlarım — listele, ekle, çıkar',
                        style: GoogleFonts.figtree(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Text('›',
                      style: GoogleFonts.figtree(
                          fontSize: 16, color: GolrivaColors.dim2)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            etiket('AYNI CİHAZDA (SIRAYLA)'),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('OYUN SEÇ',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text('· YA DA RULETE BIRAK',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: GolrivaColors.dim)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 2.7, // dar ekranda dikey tasmaya pay birak
              children: [
                // RULET: rastgele oyun ac
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      _ac(context, oyunlar[Random().nextInt(oyunlar.length)].$4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: gKartDekor(r: 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(children: [
                            gIkon('rulet', 13, GolrivaColors.goldHi),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text('RULET',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.bigShouldersDisplay(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .5,
                                      color: GolrivaColors.goldHi)),
                            ),
                          ]),
                          Text('Rastgele seçsin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.figtree(
                                    fontSize: 9, color: GolrivaColors.dim)),
                          ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
                'Aynı cihazda sırayla oynanır (hot-seat) · '
                'uzaktan oynamak için üstten davet kur.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 10.5, color: GolrivaColors.dim2)),
          ],
        ),
      ),
    );
  }
}
