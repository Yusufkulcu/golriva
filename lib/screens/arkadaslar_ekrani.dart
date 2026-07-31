import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'oyna_sekmesi.dart' show ligAdlari;

/// ARKADAŞLAR — kullanıcı adıyla ekleme (karşılıklı, onaysız MVP),
/// liste (ad · elo · lig) ve çıkarma. Sıralamanın ARKADAŞLAR filtresi
/// ve davet akışı bu listeyi kullanır.
class ArkadaslarEkrani extends StatefulWidget {
  const ArkadaslarEkrani({super.key});

  @override
  State<ArkadaslarEkrani> createState() => _ArkadaslarEkraniState();
}

class _ArkadaslarEkraniState extends State<ArkadaslarEkrani> {
  final servis = OnlineServis();
  final denetleyici = TextEditingController();
  List<({String ad, int elo, String ligKod})>? liste;
  String? hata;
  bool ekleniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    denetleyici.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi || !servis.girisYapildi) {
      setState(() => hata = 'Arkadaş listesi için çevrimiçi hesap gerekli.');
      return;
    }
    try {
      final l = await servis.arkadasListesi();
      if (mounted) setState(() => liste = l);
    } catch (e) {
      if (mounted) setState(() => hata = sunucuHataMesaji(e));
    }
  }

  Future<void> _ekle() async {
    final ad = denetleyici.text.trim();
    if (ad.isEmpty) return;
    setState(() => ekleniyor = true);
    try {
      await servis.arkadasEkle(ad);
      denetleyici.clear();
      await _yukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$ad arkadaş listene eklendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.contains('bulunamadı')
                ? 'Kullanıcı bulunamadı — adı kontrol et.'
                : '$e'.contains('kendini')
                    ? 'Kendini ekleyemezsin :)'
                    : 'Eklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => ekleniyor = false);
    }
  }

  Future<void> _sil(String ad) async {
    try {
      await servis.arkadasSil(ad);
      await _yukle();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('ARKADAŞLAR',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          children: [
            // ekleme kutusu
            Container(
              padding: const EdgeInsets.all(12),
              decoration: kartDekor(),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: denetleyici,
                    onSubmitted: (_) => _ekle(),
                    style: GoogleFonts.figtree(
                        fontSize: 14, color: GolrivaColors.ink),
                    decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Kullanıcı adıyla ekle…'),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: ekleniyor ? null : _ekle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                        gradient: GolrivaColors.goldGradient,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(ekleniyor ? '…' : 'EKLE',
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: const Color(0xFF231A04))),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            if (hata != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(hata!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        fontSize: 13, color: GolrivaColors.dim)),
              )
            else if (liste == null)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                    child:
                        CircularProgressIndicator(color: GolrivaColors.gold)),
              )
            else if (liste!.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: kartDekor(),
                child: Text(
                    'Henüz arkadaşın yok. Arkadaşının GOLRIVA kullanıcı adını '
                    'yukarıya yaz — ekleme karşılıklıdır, onay gerekmez.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        fontSize: 12.5,
                        color: GolrivaColors.dim,
                        height: 1.5)),
              )
            else ...[
              etiket('${liste!.length} ARKADAŞ'),
              const SizedBox(height: 7),
              for (final a in liste!) _satir(a),
            ],
          ],
        ),
      ),
    );
  }

  Widget _satir(({String ad, int elo, String ligKod}) a) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: kartDekor(),
        child: Row(children: [
          avatar(a.ad, 36, kenar: GolrivaColors.p2),
          const SizedBox(width: 11),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.ad,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                      fontSize: 13.5, fontWeight: FontWeight.w700)),
              Text('${a.elo} · ${ligAdlari[a.ligKod] ?? a.ligKod}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, color: GolrivaColors.dim)),
            ]),
          ),
          IconButton(
            onPressed: () => _sil(a.ad),
            icon: gIkon('carpi', 14, GolrivaColors.dim2),
            tooltip: 'Listeden çıkar',
          ),
        ]),
      );
}
