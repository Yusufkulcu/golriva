import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/hata_raporu.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'arkadaslar_ekrani.dart';

/// EKRAN 9 · SIRALAMA — 3 AKTİF filtre:
/// TÜM ZAMANLAR (Elo ilk 50 + podyum + SEN satırı),
/// HAFTALIK (son 7 günün seri galibiyetleri, sunucu RPC),
/// ARKADAŞLAR (arkadaş listesinin Elo sıralaması).
class SiralamaSekmesi extends StatefulWidget {
  const SiralamaSekmesi({super.key});

  @override
  State<SiralamaSekmesi> createState() => _SiralamaSekmesiState();
}

class _SiralamaSekmesiState extends State<SiralamaSekmesi> {
  String filtre = 'tum'; // tum / hafta / arkadas
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
    setState(() {
      liste = null;
      hata = null;
    });
    try {
      final servis = OnlineServis();
      final p = await servis.profilGetir();
      benimAdim = p?.kullaniciAdi;
      switch (filtre) {
        case 'hafta':
          final l = await servis.haftalikSiralama();
          if (mounted) setState(() => liste = l);
        case 'arkadas':
          if (!servis.girisYapildi) {
            if (mounted) {
              setState(() => hata = 'Arkadaş sıralaması için hesap gerekli.');
            }
            return;
          }
          final a = await servis.arkadasListesi();
          final l = [
            for (final x in a) (x.ad, x.elo),
            if (p != null) (p.kullaniciAdi, p.elo), // kendin de tabloda
          ]..sort((x, y) => y.$2.compareTo(x.$2));
          if (mounted) setState(() => liste = l);
        default:
          final (l, sira) = await servis.siralama();
          if (mounted) {
            setState(() {
              liste = l;
              benimSiram = sira;
            });
          }
      }
    } catch (e, s) {
      if (mounted) {
        setState(() => hata = temizMesaj('siralama._yukle', e,
            'Sıralama şu an yüklenemedi — tekrar dene.', s));
      }
    }
  }

  void _filtreSec(String f) {
    if (filtre == f) return;
    setState(() => filtre = f);
    _yukle();
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
            _filtre('tum', 'TÜM ZAMANLAR'),
            const SizedBox(width: 7),
            _filtre('hafta', 'HAFTALIK'),
            const SizedBox(width: 7),
            _filtre('arkadas', 'ARKADAŞLAR'),
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
          else if (liste!.isEmpty)
            _bosDurum()
          else ...[
            if (filtre == 'hafta')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: etiket('SON 7 GÜNÜN SERİ GALİBİYETLERİ'),
              ),
            if (liste!.length >= 3) _podyum(),
            const SizedBox(height: 10),
            for (var i = (liste!.length >= 3 ? 3 : 0); i < liste!.length; i++)
              _satir(i + 1, liste![i].$1, liste![i].$2,
                  ben: liste![i].$1 == benimAdim),
            if (filtre == 'tum' &&
                benimSiram != null &&
                benimAdim != null &&
                !liste!.take(50).any((e) => e.$1 == benimAdim))
              _satir(benimSiram!, 'SEN — $benimAdim', 0, ben: true),
            if (filtre == 'arkadas') ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _arkadaslaraGit,
                  child: const Text('ARKADAŞ EKLE / YÖNET',
                      style: TextStyle(color: GolrivaColors.goldHi)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _arkadaslaraGit() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ArkadaslarEkrani()));
    _yukle();
  }

  Widget _bosDurum() {
    final (mesaj, buton) = switch (filtre) {
      'hafta' => (
          'Bu hafta henüz seri kazanan yok — ilk sen ol!',
          false
        ),
      'arkadas' => (
          'Henüz arkadaşın yok. Kullanıcı adıyla arkadaş ekle; '
              'sıralamanız burada yarışsın.',
          true
        ),
      _ => ('Henüz sıralama verisi yok.', false),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: kartDekor(),
      child: Column(children: [
        Text(mesaj,
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
                fontSize: 12.5, color: GolrivaColors.dim, height: 1.5)),
        if (buton) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 200,
            child: goldButon('ARKADAŞ EKLE', _arkadaslaraGit, yazi: 14),
          ),
        ],
      ]),
    );
  }

  Widget _filtre(String kod, String s) {
    final aktif = filtre == kod;
    return InkWell(
      onTap: () => _filtreSec(kod),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: aktif ? const Color(0x24D4AF37) : GolrivaColors.card,
          border: Border.all(
              color: aktif ? GolrivaColors.edge : GolrivaColors.edge2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(s,
            style: GoogleFonts.figtree(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: aktif ? GolrivaColors.goldHi : GolrivaColors.dim)),
      ),
    );
  }

  /// Ilk 3 podyumu. Deger: TÜM/ARKADAŞLAR → Elo, HAFTALIK → galibiyet sayisi.
  Widget _podyum() {
    final l = liste!;
    Widget kisi(int sira, double boy, double avatarBoy, Color kenar,
        {bool tacli = false}) {
      final (ad, deger) = l[sira - 1];
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
          Text(filtre == 'hafta' ? '$deger seri' : '$deger',
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

  Widget _satir(int sira, String ad, int deger, {bool ben = false}) =>
      Container(
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
          if (deger > 0)
            Text(filtre == 'hafta' ? '$deger seri' : '$deger',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.goldHi)),
        ]),
      );
}
