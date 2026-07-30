import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// EKRAN 9 · SIRALAMA — filtre haplari, ilk 3 podyumu, liste, SEN satiri.
class SiralamaSekmesi extends StatefulWidget {
  const SiralamaSekmesi({super.key});

  @override
  State<SiralamaSekmesi> createState() => _SiralamaSekmesiState();
}

class _SiralamaSekmesiState extends State<SiralamaSekmesi> {
  List<(String, int)>? liste;
  int? benimSiram;
  String? benimAdim;
  String? hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi) {
      setState(() => hata = 'Sıralama çevrimiçi bir özellik.');
      return;
    }
    try {
      final servis = OnlineServis();
      final (l, sira) = await servis.siralama();
      final p = await servis.profilGetir();
      if (mounted) {
        setState(() {
          liste = l;
          benimSiram = sira;
          benimAdim = p?.kullaniciAdi;
        });
      }
    } catch (e) {
      if (mounted) setState(() => hata = 'Yüklenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: GolrivaColors.gold,
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Text('SIRALAMA',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            _filtre('TÜM ZAMANLAR', aktif: true),
            const SizedBox(width: 7),
            _filtre('HAFTALIK'),
            const SizedBox(width: 7),
            _filtre('ARKADAŞLAR'),
          ]),
          const SizedBox(height: 18),
          if (hata != null)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Text(hata!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                      fontSize: 13, color: GolrivaColors.dim)),
            )
          else if (liste == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child:
                      CircularProgressIndicator(color: GolrivaColors.gold)),
            )
          else ...[
            if (liste!.length >= 3) _podyum(),
            const SizedBox(height: 10),
            for (var i = (liste!.length >= 3 ? 3 : 0); i < liste!.length; i++)
              _satir(i + 1, liste![i].$1, liste![i].$2,
                  ben: liste![i].$1 == benimAdim),
            if (benimSiram != null &&
                benimAdim != null &&
                !liste!.take(50).any((e) => e.$1 == benimAdim))
              _satir(benimSiram!, 'SEN — $benimAdim', 0, ben: true),
          ],
        ],
      ),
    );
  }

  Widget _filtre(String s, {bool aktif = false}) => InkWell(
        onTap: aktif
            ? null
            : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bu filtre yakında'))),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: aktif ? const Color(0x24D4AF37) : GolrivaColors.card,
            border: Border.all(
                color: aktif ? GolrivaColors.edge : GolrivaColors.edge2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(s,
              style: GoogleFonts.figtree(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: aktif ? GolrivaColors.goldHi : GolrivaColors.dim)),
        ),
      );

  Widget _podyum() {
    final l = liste!;
    Widget kisi(int sira, double boy, double avatarBoy, Color kenar,
        {bool tacli = false}) {
      final (ad, elo) = l[sira - 1];
      return Expanded(
        flex: sira == 1 ? 11 : 10,
        child: Column(children: [
          SizedBox(
              height: 18, child: tacli ? gIkon('tac', 17) : null),
          Container(
            decoration: tacli
                ? const BoxDecoration(boxShadow: [
                    BoxShadow(color: Color(0x4DD4AF37), blurRadius: 24)
                  ], shape: BoxShape.circle)
                : null,
            child: avatar(ad, avatarBoy, kenar: kenar, kalinlik: 2),
          ),
          const SizedBox(height: 5),
          Text(ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.figtree(
                  fontSize: tacli ? 11 : 10.5,
                  fontWeight: tacli ? FontWeight.w800 : FontWeight.w700,
                  color: tacli ? GolrivaColors.goldHi : GolrivaColors.ink)),
          Text('$elo',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: tacli ? 12 : 11,
                  color: tacli ? GolrivaColors.gold : GolrivaColors.dim)),
          const SizedBox(height: 6),
          Container(
            height: boy,
            alignment: Alignment.center,
            decoration: (tacli ? gKartDekor(r: 10) : kartDekor(r: 10)).copyWith(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10))),
            child: Text('$sira',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: tacli ? 22 : 16,
                    fontWeight: FontWeight.w900,
                    color:
                        tacli ? GolrivaColors.goldHi : GolrivaColors.ink)),
          ),
        ]),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      kisi(2, 44, 52, const Color(0xFFC0C0C8)),
      const SizedBox(width: 10),
      kisi(1, 60, 62, GolrivaColors.gold, tacli: true),
      const SizedBox(width: 10),
      kisi(3, 34, 52, const Color(0xFFA87550)),
    ]);
  }

  Widget _satir(int sira, String ad, int elo, {bool ben = false}) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: ben ? gKartDekor() : kartDekor(),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: Text('$sira',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ben ? GolrivaColors.gold : GolrivaColors.dim)),
          ),
          Expanded(
            child: Text(ad,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 13,
                    fontWeight: ben ? FontWeight.w800 : FontWeight.w700,
                    color: ben ? GolrivaColors.goldHi : GolrivaColors.ink)),
          ),
          if (elo > 0)
            Text('$elo',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.goldHi)),
        ]),
      );
}
