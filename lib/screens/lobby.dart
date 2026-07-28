import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/genc_repository.dart';
import '../data/hedef_repository.dart';
import '../data/players_repository.dart';
import '../games/en_genc_kadro/screen.dart';
import '../games/en_kisa_kadro/screen.dart';
import '../games/hedefi_tuttur/screen.dart';
import '../theme/golriva_theme.dart';

class _OyunKarti {
  final String ad;
  final String etiket;
  final Widget Function()? ekran; // null = yakinda
  const _OyunKarti(this.ad, this.etiket, [this.ekran]);
}

class LobbyScreen extends StatelessWidget {
  final PlayersRepository repo;
  final GencRepository gencRepo;
  final HedefRepository hedefRepo;
  const LobbyScreen(
      {super.key,
      required this.repo,
      required this.gencRepo,
      required this.hedefRepo});

  List<_OyunKarti> get oyunlar => [
        _OyunKarti('EN KISA KADRO', 'Draft · Boy',
            () => EnKisaKadroScreen(repo: repo)),
        _OyunKarti('EN GENÇ KADRO', 'Draft · Aktifler',
            () => EnGencKadroScreen(repo: gencRepo)),
        _OyunKarti('HEDEFİ TUTTUR', 'Kör av · 14 kategori',
            () => HedefiTutturScreen(repo: hedefRepo)),
        const _OyunKarti('KUPA DRAFTI', 'Draft · 6 tur'),
        const _OyunKarti('BAYRAK YARIŞI', 'Refleks · 5 tur'),
        const _OyunKarti('BONSERVİS AVI', 'Kör av · Transfer'),
        const _OyunKarti('SARI KART AVI', 'Kör av · Kartlar'),
        const _OyunKarti('MAÇ REKORTMENLERİ', 'Serbest kadro'),
        const _OyunKarti('MİLLİ GOL KRALLARI', 'Serbest kadro'),
        const _OyunKarti('KARİYER İKİZİ', 'Soru · 5 soru'),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 10),
            Row(children: [
              // Beyin-Top isareti yer tutucusu (SVG varliklari Faz 1.1'de)
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: GolrivaColors.gold, width: 2)),
                child: const Icon(Icons.psychology_outlined,
                    size: 18, color: GolrivaColors.gold),
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  children: const [
                    TextSpan(text: 'GOL', style: TextStyle(color: GolrivaColors.gold)),
                    TextSpan(text: 'RIVA', style: TextStyle(color: GolrivaColors.ink)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Text('İyi oyunlar',
                style: GoogleFonts.figtree(fontSize: 13, color: GolrivaColors.dim)),
            Text('HOT-SEAT MVP · FAZ 1',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: oyunlar.map((o) {
                  final aktif = o.ekran != null;
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: aktif
                        ? () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => o.ekran!()))
                        : null,
                    child: Opacity(
                      opacity: aktif ? 1 : .45,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [GolrivaColors.card2, GolrivaColors.card]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: aktif ? GolrivaColors.edge : GolrivaColors.edge2),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(o.ad,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.bigShouldersDisplay(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .8,
                                      height: 1.05)),
                              const SizedBox(height: 2),
                              Text(aktif ? o.etiket : '${o.etiket} · yakında',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.figtree(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: GolrivaColors.dim)),
                            ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
