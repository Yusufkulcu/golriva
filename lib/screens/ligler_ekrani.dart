import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/hata_raporu.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// LİGLER — 7 kademeli merdiven (Amatör → Şampiyonlar Ligi).
/// İlke: Elo EŞLEŞTİRİR, Lig ÖDÜLLENDİRİR. Konfigürasyon sunucudan okunur
/// (ligler tablosu herkese açık); çevrimdışıysa bilinen değerler gösterilir.
class LiglerEkrani extends StatefulWidget {
  const LiglerEkrani({super.key});

  @override
  State<LiglerEkrani> createState() => _LiglerEkraniState();
}

typedef _Lig = ({String kod, String ad, int sira, int terfiEsigi,
    int gBo1, int kBo1, int gBo3, int kBo3});

// Çevrimdışı yedek — lig_ek.sql ile birebir aynı değerler.
const List<_Lig> _varsayilan = [
  (kod: 'amator', ad: 'Amatör Küme', sira: 1, terfiEsigi: 15,
      gBo1: 3, kBo1: 0, gBo3: 5, kBo3: 0),
  (kod: 'lig3', ad: '3. Lig', sira: 2, terfiEsigi: 18,
      gBo1: 3, kBo1: -1, gBo3: 5, kBo3: -2),
  (kod: 'lig2', ad: '2. Lig', sira: 3, terfiEsigi: 24,
      gBo1: 3, kBo1: -1, gBo3: 5, kBo3: -2),
  (kod: 'lig1', ad: '1. Lig', sira: 4, terfiEsigi: 30,
      gBo1: 3, kBo1: -2, gBo3: 5, kBo3: -3),
  (kod: 'super', ad: 'Süper Lig', sira: 5, terfiEsigi: 36,
      gBo1: 3, kBo1: -3, gBo3: 5, kBo3: -5),
  (kod: 'avrupa', ad: 'Avrupa Ligi', sira: 6, terfiEsigi: 40,
      gBo1: 2, kBo1: -3, gBo3: 3, kBo3: -5),
  (kod: 'sampiyonlar', ad: 'Şampiyonlar Ligi', sira: 7, terfiEsigi: 1000000,
      gBo1: 2, kBo1: -3, gBo3: 3, kBo3: -5),
];

class _LiglerEkraniState extends State<LiglerEkrani> {
  List<_Lig> ligler = _varsayilan;
  String? benimLig;
  int? benimPuan;

  bool yukleniyor = true; // ilk veri gelene kadar sayfa örtülü

  @override
  void initState() {
    super.initState();
    _yukle().whenComplete(() {
      if (mounted && yukleniyor) setState(() => yukleniyor = false);
    });
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi) return;
    try {
      final servis = OnlineServis();
      final l = await servis.ligler();
      final p = await servis.profilGetir();
      if (mounted) {
        setState(() {
          if (l.isNotEmpty) ligler = l;
          benimLig = p?.ligKod;
          benimPuan = p?.ligPuan;
        });
      }
    } catch (e, s) {
      hataBildir('ligler._yukle', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    // zirve ustte gorunsun diye tersten cizilir
    final sirali = [...ligler]..sort((a, b) => b.sira.compareTo(a.sira));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('LİGLER',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: YuklemeOrtusu(
          yukleniyor: yukleniyor,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          children: [
            Text('ELO EŞLEŞTİRİR · LİG ÖDÜLLENDİRİR',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 9.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.gold)),
            const SizedBox(height: 4),
            Text(
                'Ranked seri kazandıkça lig puanı toplarsın; eşiğe ulaşınca '
                'bir üst lige terfi edersin. Üst liglerde mağlubiyet puan '
                'düşürür — puanın sıfırın altına inerse bir alt lige inersin '
                '(Amatör\'den düşülmez). Berabere seride puan işlemez.',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 11, color: GolrivaColors.dim, height: 1.5)),
            const SizedBox(height: 14),
            for (final l in sirali) _ligKarti(l),
          ],
        ),
        ),
      ),
    );
  }

  Widget _ligKarti(_Lig l) {
    final buradayim = l.kod == benimLig;
    final zirve = l.sira == 7;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: buradayim ? gKartDekor() : kartDekor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          gIkon(
              zirve ? 'tac' : 'kupa_kucuk',
              16,
              buradayim
                  ? GolrivaColors.goldHi
                  : zirve
                      ? GolrivaColors.gold
                      : GolrivaColors.dim2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(trBuyuk(l.ad),
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: buradayim
                        ? GolrivaColors.goldHi
                        : GolrivaColors.ink)),
          ),
          if (buradayim)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0x24D4AF37),
                  border: Border.all(color: GolrivaColors.edge),
                  borderRadius: BorderRadius.circular(30)),
              child: Text('BURADASIN',
                  style: GoogleFonts.figtree(
                      fontSize: 8.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: GolrivaColors.goldHi)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(
            zirve
                ? 'Zirve — puan sezon şeref sıralaması için birikir'
                : 'Terfi: ${l.terfiEsigi} puan',
            style: GoogleFonts.figtree(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: buradayim ? GolrivaColors.gold : GolrivaColors.dim)),
        Text(
            'Tek maç: galibiyet +${l.gBo1} / mağlubiyet ${l.kBo1}   ·   '
            'Bo3: +${l.gBo3} / ${l.kBo3}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10, color: GolrivaColors.dim2)),
        if (buradayim && benimPuan != null && !zirve) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: ilerleme(benimPuan! / l.terfiEsigi, yukseklik: 6)),
            const SizedBox(width: 10),
            Text('$benimPuan/${l.terfiEsigi}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, color: GolrivaColors.goldHi)),
          ]),
        ],
      ]),
    );
  }
}
