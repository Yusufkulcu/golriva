import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/kayit_ekrani.dart';
import '../online/online_servis.dart';
import '../online/oyun_yonlendirici.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'ligler_ekrani.dart';
import 'oyna_sekmesi.dart';

const _aylar = [
  '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
];

/// EKRAN 10 · PROFİL — avatar, kimlik, ELO/SERİ/GALİBİYET, lig kartı,
/// oyun performansı, rozetler.
class ProfilSekmesi extends StatefulWidget {
  const ProfilSekmesi({super.key});

  @override
  State<ProfilSekmesi> createState() => _ProfilSekmesiState();
}

class _ProfilSekmesiState extends State<ProfilSekmesi> {
  OnlineProfil? profil;
  int? siram;
  ({int seri, int galibiyet, Map<String, (int, int)> oyunlar})? ist;
  bool yuklendi = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi) {
      setState(() => yuklendi = true);
      return;
    }
    try {
      final servis = OnlineServis();
      final p = await servis.profilGetir();
      ({int seri, int galibiyet, Map<String, (int, int)> oyunlar})? i;
      int? sira;
      if (p != null) {
        i = await servis.istatistik();
        final (_, s) = await servis.siralama();
        sira = s;
      }
      if (mounted) {
        setState(() {
          profil = p;
          ist = i;
          siram = sira;
          yuklendi = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => yuklendi = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!yuklendi) {
      return const Center(
          child: CircularProgressIndicator(color: GolrivaColors.gold));
    }
    if (profil == null) return _hesapYok();
    final p = profil!;
    final uyelik = p.uyelik == null
        ? ''
        : 'Üyelik: ${_aylar[p.uyelik!.month]} ${p.uyelik!.year} · Türkiye';
    return RefreshIndicator(
      color: GolrivaColors.gold,
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Center(
              child: avatar(p.kullaniciAdi, 76,
                  kenar: GolrivaColors.gold, kalinlik: 2.5)),
          const SizedBox(height: 8),
          Center(
            child: Text(p.kullaniciAdi.toUpperCase(),
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ),
          Center(
            child: Text(uyelik,
                style: GoogleFonts.figtree(
                    fontSize: 10.5, color: GolrivaColors.dim)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _stat('${p.elo}', siram == null ? 'ELO' : 'ELO · #$siram',
                altin: true),
            const SizedBox(width: 8),
            _stat('${ist?.seri ?? 0}', 'SERİ MAÇI'),
            const SizedBox(width: 8),
            _stat(
                ist == null || ist!.seri == 0 ? '—' : '%${ist!.galibiyet}',
                'GALİBİYET',
                renk: GolrivaColors.ok),
          ]),
          const SizedBox(height: 9),
          // lig kartı → LİGLER sayfası
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LiglerEkrani())),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: gKartDekor(),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ligAdlari[p.ligKod] ?? p.ligKod,
                    style: GoogleFonts.bigShouldersDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: GolrivaColors.goldHi)),
                Text('Sezon 1',
                    style: GoogleFonts.figtree(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: GolrivaColors.dim)),
              ]),
              const SizedBox(width: 12),
              Expanded(child: ilerleme(p.ligPuan / 30, yukseklik: 6)),
              const SizedBox(width: 10),
              Text('${p.ligPuan}/30',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: GolrivaColors.goldHi)),
            ]),
            ),
          ),
          const SizedBox(height: 15),
          Text('OYUN PERFORMANSI',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          if (ist == null || ist!.oyunlar.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: kartDekor(),
              child: Text('Henüz çevrimiçi maç oynanmadı.',
                  style: GoogleFonts.figtree(
                      fontSize: 12, color: GolrivaColors.dim)),
            )
          else
            for (final e in ist!.oyunlar.entries) _performans(e.key, e.value),
          const SizedBox(height: 13),
          Text('ROZETLER',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          Row(children: [
            _rozet('kupa_kucuk', acik: (ist?.seri ?? 0) > 0),
            const SizedBox(width: 8),
            _rozet('alev', acik: (ist?.galibiyet ?? 0) >= 50),
            const SizedBox(width: 8),
            _rozet('simsek', acik: (ist?.seri ?? 0) >= 10),
            const SizedBox(width: 8),
            _rozet('hedefi_tuttur', acik: false),
          ]),
        ],
      ),
    );
  }

  Widget _hesapYok() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            avatar('?', 76),
            const SizedBox(height: 12),
            Text('HESAP YOK',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Text(
                SupabaseAyar.yapilandirildi
                    ? 'Çevrimiçi profil için bir hesap aç — 500 RIVA hediye.'
                    : 'Profil çevrimiçi bir özellik (README_SUPABASE.md).',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 12.5, color: GolrivaColors.dim)),
            if (SupabaseAyar.yapilandirildi) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 220,
                child: goldButon('HESAP AÇ · +500 RIVA', () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const KayitEkrani()));
                  _yukle();
                }, yazi: 15),
              ),
            ],
          ]),
        ),
      );

  Widget _stat(String deger, String ad,
          {bool altin = false, Color renk = GolrivaColors.ink}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: altin ? gKartDekor() : kartDekor(),
          child: Column(children: [
            Text(deger,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: altin ? GolrivaColors.goldHi : renk)),
            const SizedBox(height: 1),
            Text(ad,
                style: GoogleFonts.figtree(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.dim)),
          ]),
        ),
      );

  Widget _performans(String kod, (int, int) skor) {
    final oran = skor.$2 == 0 ? 0.0 : skor.$1 / skor.$2;
    final iyi = oran >= .5;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: kartDekor(),
      child: Row(children: [
        Expanded(
          child: Text(onlineOyunAdlari[kod] ?? kod,
              style: GoogleFonts.figtree(
                  fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          width: 90,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: oran,
              minHeight: 5,
              backgroundColor: GolrivaColors.card2,
              valueColor: AlwaysStoppedAnimation(
                  iyi ? GolrivaColors.gold : const Color(0xFF9A9AA4)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('%${(oran * 100).round()}',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: iyi ? GolrivaColors.goldHi : GolrivaColors.dim)),
      ]),
    );
  }

  Widget _rozet(String ikon, {required bool acik}) => Opacity(
        opacity: acik ? 1 : .35,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: acik ? gKartDekor(r: 14) : kartDekor(r: 14),
          child: gIkon(ikon, 22, acik ? GolrivaColors.gold : GolrivaColors.dim),
        ),
      );
}
