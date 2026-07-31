import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../main.dart' show rotaGozcusu;
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'oyna_sekmesi.dart';
import 'profil_sekmesi.dart';
import 'siralama_sekmesi.dart';

/// UYGULAMA ISKELETI — 3 sekme: OYNA · SIRALAMA · PROFİL
/// (Düellolar artık profilin altında — kullanıcı istegi).
///
/// OTOMATIK TAZELIK (kullanici kurali: "sayfaya girince guncel veri"):
/// - Sekme degisince sayfa YENIDEN kurulur (taze sorgu).
/// - Herhangi bir sayfadan geri donulunce (mac, cuzdan, arama...)
///   RouteObserver tetiklenir ve aktif sekme yeniden kurulur.
class AnaIskelet extends StatefulWidget {
  final GolrivaRepos repos;
  const AnaIskelet({super.key, required this.repos});

  @override
  State<AnaIskelet> createState() => _AnaIskeletState();
}

class _AnaIskeletState extends State<AnaIskelet> with RouteAware {
  int sekme = 0;
  int tazelik = 0; // her artis aktif sekmeyi sifirdan kurar

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rota = ModalRoute.of(context);
    if (rota != null) rotaGozcusu.subscribe(this, rota);
  }

  @override
  void dispose() {
    rotaGozcusu.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // ustumuzdeki sayfa kapandi (mac bitti, cuzdan kapandi...) → tazele
    setState(() => tazelik++);
  }

  @override
  Widget build(BuildContext context) {
    final sayfa = switch (sekme) {
      1 => SiralamaSekmesi(key: ValueKey('siralama-$tazelik')),
      2 => ProfilSekmesi(key: ValueKey('profil-$tazelik')),
      _ => OynaSekmesi(
          key: ValueKey('oyna-$tazelik'),
          repos: widget.repos,
          onProfil: () => setState(() {
                sekme = 2;
                tazelik++;
              })),
    };
    return Scaffold(
      body: SafeArea(bottom: false, child: sayfa),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: GolrivaColors.bg,
          border: Border(top: BorderSide(color: GolrivaColors.edge2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              children: [
                Expanded(child: _sekmeButonu(0, 'nav_oyna', 'OYNA')),
                Expanded(child: _sekmeButonu(1, 'nav_siralama', 'SIRALAMA')),
                Expanded(child: _sekmeButonu(2, 'nav_profil', 'PROFİL')),
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
      onTap: () => setState(() {
        sekme = i;
        tazelik++; // ayni sekmeye bassa bile taze veri
      }),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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
