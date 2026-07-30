import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
import '../online/kayit_ekrani.dart';
import '../online/kuyruk_ekrani.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';

class _OyunKarti {
  final String ad;
  final String etiket;
  final String ikon; // assets/icons/*.svg
  final Widget Function() ekran;
  const _OyunKarti(this.ad, this.etiket, this.ikon, this.ekran);
}

/// FAZ 2 cevrimici seridi: hesap yoksa "ÇEVRİMİÇİ OYNA", varsa
/// kullanici adi + RIVA bakiyesi + RANKED butonu. Supabase yapilandirilmamis
/// derlemelerde HIC gorunmez (tam cevrimdisi calisma korunur).
class OnlineSerit extends StatefulWidget {
  final GolrivaRepos repos;
  const OnlineSerit({super.key, required this.repos});

  @override
  State<OnlineSerit> createState() => _OnlineSeritState();
}

class _OnlineSeritState extends State<OnlineSerit> {
  OnlineProfil? profil;
  bool yuklendi = false;

  @override
  void initState() {
    super.initState();
    _yenile();
  }

  Future<void> _yenile() async {
    if (!SupabaseAyar.yapilandirildi) {
      setState(() => yuklendi = true);
      return;
    }
    try {
      final p = await OnlineServis().profilGetir();
      if (mounted) {
        setState(() {
          profil = p;
          yuklendi = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => yuklendi = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseAyar.yapilandirildi || !yuklendi) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x18D4AF37), GolrivaColors.card]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GolrivaColors.edge),
      ),
      child: profil == null
          ? Row(children: [
              Expanded(
                child: Text('Çevrimiçi maçlar için hesap aç',
                    style: GoogleFonts.figtree(
                        fontSize: 12, color: GolrivaColors.dim)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: GolrivaColors.gold,
                    foregroundColor: const Color(0xFF231A04),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8)),
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KayitEkrani()));
                  _yenile();
                },
                child: Text('+500 RIVA',
                    style: GoogleFonts.bigShouldersDisplay(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 14)),
              ),
            ])
          : Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profil!.kullaniciAdi,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.figtree(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: GolrivaColors.ink)),
                      Text('${profil!.bakiye} RIVA · Elo ${profil!.elo}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, color: GolrivaColors.goldHi)),
                    ]),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: GolrivaColors.goldHi,
                    side: const BorderSide(color: GolrivaColors.edge),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8)),
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => KuyrukEkrani(
                              profil: profil!, repos: widget.repos)));
                  _yenile();
                },
                child: Text('RANKED',
                    style: GoogleFonts.bigShouldersDisplay(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 14)),
              ),
            ]),
    );
  }
}

class LobbyScreen extends StatelessWidget {
  final GolrivaRepos repos;
  const LobbyScreen({super.key, required this.repos});

  List<_OyunKarti> get _oyunlar => [
        _OyunKarti('EN KISA KADRO', 'Draft · Boy', 'en_kisa_kadro',
            () => EnKisaKadroScreen(repo: repos.boy)),
        _OyunKarti('KUPA DRAFTI', 'Draft · Kupalar', 'kupa_drafti',
            () => KupaDraftiScreen(repo: repos.kupa)),
        _OyunKarti('EN GENÇ KADRO', 'Draft · Aktifler', 'en_genc_kadro',
            () => EnGencKadroScreen(repo: repos.genc)),
        _OyunKarti('BAYRAK YARIŞI', 'Refleks · 5 tur', 'bayrak_yarisi',
            () => BayrakYarisiScreen(repo: repos.boy)),
        _OyunKarti('HEDEFİ TUTTUR', 'Kör av · 14 kategori', 'hedefi_tuttur',
            () => HedefiTutturScreen(repo: repos.hedef)),
        _OyunKarti('BONSERVİS AVI', 'Kör av · Transfer', 'bonservis_avi',
            () => KorAvScreen(repo: repos.fee, config: bonservisConfig)),
        _OyunKarti('SARI KART AVI', 'Kör av · Kartlar', 'sari_kart_avi',
            () => KorAvScreen(repo: repos.card, config: sariKartConfig)),
        _OyunKarti(
            'MAÇ REKORTMENLERİ',
            'Serbest kadro · Maç',
            'mac_rekortmenleri',
            () => SerbestKadroScreen(repo: repos.mac, config: macConfig)),
        _OyunKarti(
            'MİLLİ GOL KRALLARI',
            'Serbest kadro · Gol',
            'milli_gol_krallari',
            () =>
                SerbestKadroScreen(repo: repos.milligol, config: milligolConfig)),
        _OyunKarti('KARİYER İKİZİ', 'Soru · 5 soru', 'kariyer_ikizi',
            () => KariyerIkiziScreen(repo: repos.ikiz)),
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
              // K1 Beyin-Top — yari beyin (altin), yari top (beyaz)
              SvgPicture.asset('assets/brand/beyin_top.svg',
                  width: 36, height: 36),
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
            const SizedBox(height: 12),
            // FAZ 2: cevrimici serit — Supabase yapilandirilmadiysa gorunmez
            OnlineSerit(repos: repos),
            const SizedBox(height: 4),
            Text('İyi oyunlar',
                style: GoogleFonts.figtree(fontSize: 13, color: GolrivaColors.dim)),
            Text('HOT-SEAT MVP · 10 OYUN',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: _oyunlar.map((o) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => o.ekran())),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [GolrivaColors.card2, GolrivaColors.card]),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: GolrivaColors.edge),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Expanded: ikon alani esner — en dar ekranda
                            // metinler yer kazanir, tasma matematiksel olarak
                            // imkansizlasir (0.143px dersi).
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: SvgPicture.asset(
                                    'assets/icons/${o.ikon}.svg',
                                    width: 22,
                                    height: 22,
                                    colorFilter: const ColorFilter.mode(
                                        GolrivaColors.gold, BlendMode.srcIn)),
                              ),
                            ),
                            Text(o.ad,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.bigShouldersDisplay(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .8,
                                    height: 1.05)),
                            const SizedBox(height: 2),
                            Text(o.etiket,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.figtree(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: GolrivaColors.dim)),
                          ]),
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
