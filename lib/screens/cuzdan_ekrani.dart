import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// CÜZDAN — bakiye + hareket GEÇMİŞİ (harcamalar/kazanımlar).
/// Riva KAZANMA ve SATIN ALMA artik MAĞAZA sekmesinde (kullanıcı isteği:
/// satın alma alanı belirgin olsun; "düello kazanarak" bilgi kartı kaldırıldı).
class CuzdanEkrani extends StatefulWidget {
  const CuzdanEkrani({super.key});

  @override
  State<CuzdanEkrani> createState() => _CuzdanEkraniState();
}

class _CuzdanEkraniState extends State<CuzdanEkrani> {
  int? bakiye;
  List<({String tip, int miktar, String? aciklama, DateTime tarih})>? gecmis;

  static const _aylar = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
  ];
  static const _tipAdlari = {
    'baslangic': 'Hoş geldin hediyesi',
    'seri_giris': 'Seri girişi',
    'seri_odul': 'Seri ödülü',
    'berabere_iade': 'Berabere iadesi',
    'reklam': 'Reklam ödülü',
    'paket': 'Paket alımı',
    'duzeltme': 'Düzeltme',
  };

  @override
  void initState() {
    super.initState();
    if (SupabaseAyar.yapilandirildi) {
      final servis = OnlineServis();
      servis.profilGetir().then((p) {
        if (mounted) setState(() => bakiye = p?.bakiye);
      }).catchError((_) {});
      servis.defterGecmisi().then((g) {
        if (mounted) setState(() => gecmis = g);
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('CÜZDAN',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: gKartDekor(r: 24),
              child: Column(children: [
                gIkon('riva', 34),
                const SizedBox(height: 6),
                Text(bakiye == null ? '—' : '$bakiye',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: GolrivaColors.goldHi)),
                const SizedBox(height: 3),
                etiket('RIVA'),
                const SizedBox(height: 6),
                Text('Riva kazanmak ve satın almak için MAĞAZA sekmesine bak.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        fontSize: 10.5, color: GolrivaColors.dim2)),
              ]),
            ),
            const SizedBox(height: 15),
            Text('GEÇMİŞ',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            if (gecmis == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: kartDekor(),
                child: Text(
                    SupabaseAyar.yapilandirildi
                        ? 'Yükleniyor…'
                        : 'Cüzdan çevrimiçi bir özellik.',
                    style: GoogleFonts.figtree(
                        fontSize: 12, color: GolrivaColors.dim)),
              )
            else if (gecmis!.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: kartDekor(),
                child: Text('Henüz hareket yok.',
                    style: GoogleFonts.figtree(
                        fontSize: 12, color: GolrivaColors.dim)),
              )
            else
              for (final h in gecmis!) _hareket(h),
            const SizedBox(height: 24),
            Text('Riva yalnız oyun girişinde kullanılır · Elo satın alınamaz',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 9.5, color: GolrivaColors.dim2, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _hareket(
      ({String tip, int miktar, String? aciklama, DateTime tarih}) h) {
    final arti = h.miktar >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: kartDekor(r: 14),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_tipAdlari[h.tip] ?? h.tip,
                style: GoogleFonts.figtree(
                    fontSize: 12, fontWeight: FontWeight.w700)),
            Text(
                '${h.tarih.day} ${_aylar[h.tarih.month]}'
                '${h.aciklama == null ? "" : " · ${h.aciklama}"}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 9.5, color: GolrivaColors.dim)),
          ]),
        ),
        Text('${arti ? "+" : ""}${h.miktar}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: arti ? GolrivaColors.ok : GolrivaColors.bad)),
      ]),
    );
  }
}
