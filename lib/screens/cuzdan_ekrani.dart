import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../reklam/reklam_servis.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// EKRAN 11 · CÜZDAN — bakiye, RIVA KAZAN (reklam/düello), PAKETLER (yakında).
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

  void _yakinda(String s) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(s)));

  bool reklamOynuyor = false;

  /// ODULLU REKLAM AKISI: reklami goster → odul kazanildiysa sunucudan
  /// tahsil et (kurallar sunucuda) → bakiye + gecmisi tazele.
  Future<void> _reklamIzle() async {
    if (!ReklamServis.destekleniyor) {
      _yakinda('Reklamlar yalnız telefonda (Android/iOS) gösterilir.');
      return;
    }
    final servis = OnlineServis();
    if (!SupabaseAyar.yapilandirildi || !servis.girisYapildi) {
      _yakinda('Reklam ödülü için çevrimiçi hesap gerekli.');
      return;
    }
    if (reklamOynuyor) return;
    setState(() => reklamOynuyor = true);
    try {
      final islem = await ReklamServis.odulluGoster();
      if (islem == null) {
        // neden ekranda gorunsun — tani koyabilmek icin (kod 0/1/2/3)
        final neden = ReklamServis.sonHata;
        _yakinda(neden == null
            ? 'Reklam şu an yüklenemedi — birazdan tekrar dene.'
            : 'Reklam gösterilemedi · $neden');
        return;
      }
      final odul = await servis.reklamOdulAl(islem);
      final p = await servis.profilGetir();
      final g = await servis.defterGecmisi();
      if (mounted) {
        setState(() {
          bakiye = p?.bakiye;
          gecmis = g;
        });
        _yakinda('+$odul RIVA cüzdanında!');
      }
    } catch (e) {
      final m = '$e';
      _yakinda(m.contains('tavan')
          ? 'Günlük reklam hakkın doldu (10/10) — yarın yine gel!'
          : m.contains('Could not find the')
              ? 'Sunucu güncellemesi gerekli: Supabase SQL editöründe '
                  'supabase/faz2_5_reklam.sql çalıştırılmalı.'
              : 'Ödül işlenemedi: $e');
    } finally {
      if (mounted) setState(() => reklamOynuyor = false);
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
              ]),
            ),
            const SizedBox(height: 15),
            Text('RIVA KAZAN',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _reklamIzle,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: gKartDekor(),
                child: Row(children: [
                  reklamOynuyor
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: GolrivaColors.gold, strokeWidth: 2.5))
                      : gIkon('oynat', 22, GolrivaColors.goldHi),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              reklamOynuyor
                                  ? 'Reklam yükleniyor…'
                                  : 'Reklam izle',
                              style: GoogleFonts.figtree(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('Günde 10 hak',
                              style: GoogleFonts.figtree(
                                  fontSize: 10, color: GolrivaColors.dim)),
                        ]),
                  ),
                  Text('+50',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GolrivaColors.ok)),
                ]),
              ),
            ),
            const SizedBox(height: 7),
            Opacity(
              opacity: .75,
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: kartDekor(),
                child: Row(children: [
                  gIkon('nav_duellolar', 22, GolrivaColors.dim2),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Düello kazan',
                              style: GoogleFonts.figtree(
                                  fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('Klasik masada galibiyet',
                              style: GoogleFonts.figtree(
                                  fontSize: 10, color: GolrivaColors.dim)),
                        ]),
                  ),
                  Text('+70',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: GolrivaColors.dim)),
                ]),
              ),
            ),
            const SizedBox(height: 15),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('PAKETLER',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: etiket('· YAKINDA'),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _paket('500', 'Riva'),
              const SizedBox(width: 8),
              _paket('1.500', 'Riva · popüler', altin: true),
              const SizedBox(width: 8),
              _paket('5.000', 'Riva'),
            ]),
            // ── GEÇMİŞ: harcamalar + kazanımlar (defter) ──
            if (gecmis != null) ...[
              const SizedBox(height: 15),
              Text('GEÇMİŞ',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              if (gecmis!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: kartDekor(),
                  child: Text('Henüz hareket yok.',
                      style: GoogleFonts.figtree(
                          fontSize: 12, color: GolrivaColors.dim)),
                )
              else
                for (final h in gecmis!) _hareket(h),
            ],
            const SizedBox(height: 30),
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

  Widget _paket(String miktar, String alt, {bool altin = false}) => Expanded(
        child: Opacity(
          opacity: .5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: kartDekor().copyWith(
                border: Border.all(
                    color: altin ? GolrivaColors.edge : GolrivaColors.edge2)),
            child: Column(children: [
              Text(miktar,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color:
                          altin ? GolrivaColors.goldHi : GolrivaColors.ink)),
              const SizedBox(height: 2),
              Text(alt,
                  style: GoogleFonts.figtree(
                      fontSize: 9, color: GolrivaColors.dim)),
            ]),
          ),
        ),
      );
}
