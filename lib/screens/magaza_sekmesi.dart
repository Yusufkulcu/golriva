import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/hata_raporu.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../reklam/reklam_servis.dart';
import '../satinalma/satinalma_servis.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'cuzdan_ekrani.dart';

/// SEKME · MAĞAZA — Riva'nın tek adresi (kullanıcı isteği: satın alma
/// alanı alt menüde, tasarımı belirgin, FİYATLAR görünür):
/// bakiye, ödüllü reklam (+50) ve Riva paketleri (canlı mağaza fiyatı,
/// çekilemezse admin panelden girilen görünüm fiyatı).
class MagazaSekmesi extends StatefulWidget {
  const MagazaSekmesi({super.key});

  @override
  State<MagazaSekmesi> createState() => _MagazaSekmesiState();
}

class _MagazaSekmesiState extends State<MagazaSekmesi> {
  int? bakiye;
  List<({String kod, String ad, int riva, String? fiyatMetni})> paketler =
      const [
    (kod: 'riva_500', ad: 'Başlangıç', riva: 500, fiyatMetni: null),
    (kod: 'riva_1500', ad: 'Popüler', riva: 1500, fiyatMetni: null),
    (kod: 'riva_5000', ad: 'Kral', riva: 5000, fiyatMetni: null),
  ];
  Map<String, String> canliFiyatlar = {};
  bool reklamOynuyor = false;
  bool satinAliniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi) return;
    final servis = OnlineServis();
    servis.profilGetir().then((p) {
      if (mounted) setState(() => bakiye = p?.bakiye);
    }).catchError((Object e, StackTrace s) {
      hataBildir('magaza._yukle.profil', e, s);
    });
    try {
      final u = await servis.urunler();
      if (u.isNotEmpty && mounted) setState(() => paketler = u);
    } catch (e, s) {
      hataBildir('magaza._yukle.urunler', e, s); // bilinen paketler kalir
    }
    // canli magaza fiyatlari (kullanicinin para birimiyle)
    try {
      final f = await SatinAlmaServis.fiyatlar(
          paketler.map((p) => p.kod).toSet());
      if (f.isNotEmpty && mounted) setState(() => canliFiyatlar = f);
    } catch (_) {}
  }

  void _mesaj(String s) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(s)));

  static String _binlik(int n) {
    final s = '$n';
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _fiyat(({String kod, String ad, int riva, String? fiyatMetni}) p) =>
      canliFiyatlar[p.kod] ?? p.fiyatMetni ?? 'Mağazada';

  // ── ODULLU REKLAM (cuzdandan buraya tasindi) ──
  Future<void> _reklamIzle() async {
    if (!ReklamServis.destekleniyor) {
      _mesaj('Reklamlar yalnız telefonda (Android/iOS) gösterilir.');
      return;
    }
    final servis = OnlineServis();
    if (!SupabaseAyar.yapilandirildi || !servis.girisYapildi) {
      _mesaj('Reklam ödülü için çevrimiçi hesap gerekli.');
      return;
    }
    if (reklamOynuyor) return;
    setState(() => reklamOynuyor = true);
    try {
      final islem = await ReklamServis.odulluGoster();
      if (islem == null) {
        // Teknik neden (kod 3, no-fill, SDK...) yalniz admin'e gider.
        final neden = ReklamServis.sonHata;
        if (neden != null) hataBildir('magaza._reklamIzle', neden);
        _mesaj('Reklam şu an gösterilemedi — birazdan tekrar dene.');
        return;
      }
      final odul = await servis.reklamOdulAl(islem);
      final p = await servis.profilGetir();
      if (mounted) {
        setState(() => bakiye = p?.bakiye);
        _mesaj('+$odul RIVA cüzdanında!');
      }
    } catch (e, s) {
      final m = '$e';
      _mesaj(m.contains('tavan')
          ? 'Günlük reklam hakkın doldu (10/10) — yarın yine gel!'
          : temizMesaj('magaza._reklamOdul', e,
              'Ödül şu an işlenemedi — birazdan tekrar dene.', s));
    } finally {
      if (mounted) setState(() => reklamOynuyor = false);
    }
  }

  // ── SATIN ALMA ──
  Future<void> _satinAl(String urunKodu) async {
    final servis = OnlineServis();
    if (!SupabaseAyar.yapilandirildi || !servis.girisYapildi) {
      _mesaj('Satın alma için çevrimiçi hesap gerekli.');
      return;
    }
    if (satinAliniyor) return;
    setState(() => satinAliniyor = true);
    try {
      final sonuc = await SatinAlmaServis.satinAl(urunKodu);
      if (sonuc.islemId == null) {
        _mesaj(sonuc.hata ?? 'Satın alma tamamlanamadı.');
        return;
      }
      final odul = await servis.satinAlmaOdul(
          SatinAlmaServis.magaza, urunKodu, sonuc.islemId!);
      final p = await servis.profilGetir();
      if (mounted) {
        setState(() => bakiye = p?.bakiye);
        _mesaj('+$odul RIVA cüzdanında — teşekkürler!');
      }
    } catch (e, s) {
      // Teknik neden (or. faz2_7_market.sql eksik) admin paneline raporlanir.
      _mesaj(temizMesaj('magaza._satinAl', e,
          'Ödül işlenirken sorun oluştu — mağaza işlemin kayıtlı, '
          'destekle iletişime geç.', s));
    } finally {
      if (mounted) setState(() => satinAliniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('MAĞAZA',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const Spacer(),
          // bakiye + cuzdan gecmisi kisayolu
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CuzdanEkrani())),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: gKartDekor(r: 30),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                gIkon('riva', 15),
                const SizedBox(width: 6),
                Text(bakiye == null ? '—' : _binlik(bakiye!),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: GolrivaColors.goldHi)),
                const SizedBox(width: 4),
                Text('›',
                    style: GoogleFonts.figtree(
                        fontSize: 14, color: GolrivaColors.dim2)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Riva yalnız oyun girişinde kullanılır · Elo satın alınamaz',
            style:
                GoogleFonts.figtree(fontSize: 10, color: GolrivaColors.dim2)),
        const SizedBox(height: 14),
        // ── BEDAVA RIVA: odullu reklam ──
        etiket('BEDAVA RIVA'),
        const SizedBox(height: 7),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _reklamIzle,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: gKartDekor(),
            child: Row(children: [
              reklamOynuyor
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: GolrivaColors.gold, strokeWidth: 2.5))
                  : gIkon('oynat', 24, GolrivaColors.goldHi),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reklamOynuyor ? 'Reklam yükleniyor…' : 'Reklam izle',
                          style: GoogleFonts.figtree(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('Günde 10 hak · her izleme +50 Riva',
                          style: GoogleFonts.figtree(
                              fontSize: 10.5, color: GolrivaColors.dim)),
                    ]),
              ),
              Text('+50',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.ok)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // ── RIVA PAKETLERI (fiyatli, buyuk kartlar) ──
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          etiket('RIVA PAKETLERİ'),
          const SizedBox(width: 6),
          Expanded(
            child: Text('· güvenli mağaza ödemesi (Google/Apple)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 9, color: GolrivaColors.dim2)),
          ),
        ]),
        const SizedBox(height: 7),
        for (var i = 0; i < paketler.length; i++) _paketKarti(paketler[i], i),
        const SizedBox(height: 6),
        Text(
            'Satın alma Google Play / App Store üzerinden yapılır; '
            'Riva anında cüzdanına işlenir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
                fontSize: 10, color: GolrivaColors.dim2, height: 1.5)),
      ],
    );
  }

  Widget _paketKarti(
      ({String kod, String ad, int riva, String? fiyatMetni}) p, int i) {
    final one = i == 1; // ikinci paket vitrinde (populer)
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: satinAliniyor ? null : () => _satinAl(p.kod),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: one ? gKartDekor(r: 20) : kartDekor(r: 20),
          child: Row(children: [
            gIkon('riva', 30, one ? GolrivaColors.goldHi : GolrivaColors.gold),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FittedBox: dar ekranda miktar+RIVA kuculerek sigar
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        goldYazi(_binlik(p.riva), boyut: 24, bosluk: 1),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: etiket('RIVA'),
                        ),
                      ]),
                    ),
                    Text(p.ad,
                        style: GoogleFonts.figtree(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: GolrivaColors.dim)),
                  ]),
            ),
            // FIYAT — kullanici istegi: ne kadara satildigi belli olsun
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                gradient: one ? GolrivaColors.goldGradient : null,
                color: one ? null : GolrivaColors.card2,
                border:
                    one ? null : Border.all(color: GolrivaColors.edge),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(satinAliniyor ? '…' : _fiyat(p),
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: one
                          ? const Color(0xFF231A04)
                          : GolrivaColors.goldHi)),
            ),
          ]),
        ),
      ),
    );
  }
}
