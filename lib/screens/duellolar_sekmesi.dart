import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

const _aylar = [
  '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
];

/// SEKME · DÜELLOLAR — biten serilerin gecmisi (rakip, skor, sonuc).
class DuellolarSekmesi extends StatefulWidget {
  const DuellolarSekmesi({super.key});

  @override
  State<DuellolarSekmesi> createState() => _DuellolarSekmesiState();
}

class _DuellolarSekmesiState extends State<DuellolarSekmesi> {
  List<({String rakip, int s1, int s2, bool? kazandim, String mod,
      DateTime tarih, bool benP1})>? liste;
  String? hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi) {
      setState(() => hata = 'Düello geçmişi çevrimiçi bir özellik.');
      return;
    }
    try {
      final l = await OnlineServis().macGecmisi();
      if (mounted) setState(() => liste = l);
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
          Text('DÜELLOLAR',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
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
          else if (liste!.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: kartDekor(),
              child: Text(
                  'Henüz biten düello yok — OYNA sekmesinden HIZLI DÜELLO ile başla!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                      fontSize: 12.5, color: GolrivaColors.dim)),
            )
          else
            for (final m in liste!) _seriKarti(m),
        ],
      ),
    );
  }

  Widget _seriKarti(
      ({String rakip, int s1, int s2, bool? kazandim, String mod,
          DateTime tarih, bool benP1}) m) {
    final skorum = m.benP1 ? m.s1 : m.s2;
    final skorRakip = m.benP1 ? m.s2 : m.s1;
    final (durum, renk) = m.kazandim == null
        ? ('BERABERE', GolrivaColors.dim)
        : m.kazandim!
            ? ('GALİBİYET', GolrivaColors.ok)
            : ('MAĞLUBİYET', GolrivaColors.bad);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: (m.kazandim ?? false) ? gKartDekor() : kartDekor(),
      child: Row(children: [
        avatar(m.rakip, 36, kenar: GolrivaColors.p2),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.rakip,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text(
                '${m.mod.toUpperCase()} · ${m.tarih.day} ${_aylar[m.tarih.month]}',
                style: GoogleFonts.figtree(
                    fontSize: 10, color: GolrivaColors.dim)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$skorum - $skorRakip',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.goldHi)),
          Text(durum,
              style: GoogleFonts.figtree(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: renk)),
        ]),
      ]),
    );
  }
}
