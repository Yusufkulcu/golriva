import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'duellolar_sekmesi.dart';
import 'oyna_sekmesi.dart';
import 'profil_sekmesi.dart';
import 'siralama_sekmesi.dart';

/// UYGULAMA ISKELETI — golriva_ekranlar_v1.html'deki 4 sekmeli yapi:
/// OYNA · SIRALAMA · DÜELLOLAR · PROFİL (tabbar2 birebir).
class AnaIskelet extends StatefulWidget {
  final GolrivaRepos repos;
  const AnaIskelet({super.key, required this.repos});

  @override
  State<AnaIskelet> createState() => _AnaIskeletState();
}

class _AnaIskeletState extends State<AnaIskelet> {
  int sekme = 0;

  @override
  Widget build(BuildContext context) {
    final sayfalar = [
      OynaSekmesi(repos: widget.repos),
      const SiralamaSekmesi(),
      const DuellolarSekmesi(),
      const ProfilSekmesi(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: sekme, children: sayfalar)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: GolrivaColors.bg,
          border: Border(top: BorderSide(color: GolrivaColors.edge2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sekmeButonu(0, 'nav_oyna', 'OYNA'),
                _sekmeButonu(1, 'nav_siralama', 'SIRALAMA'),
                _sekmeButonu(2, 'nav_duellolar', 'DÜELLOLAR'),
                _sekmeButonu(3, 'nav_profil', 'PROFİL'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sekmeButonu(int i, String ikon, String ad) {
    final aktif = sekme == i;
    final renk = aktif ? GolrivaColors.goldHi : GolrivaColors.dim2;
    return InkWell(
      onTap: () => setState(() => sekme = i),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: aktif
                ? const BoxDecoration(boxShadow: [
                    BoxShadow(color: Color(0x73F0D67C), blurRadius: 12)
                  ])
                : null,
            child: gIkon(ikon, 20, renk),
          ),
          const SizedBox(height: 4),
          Text(ad,
              style: GoogleFonts.figtree(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                  color: renk)),
        ]),
      ),
    );
  }
}
