import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../online/arama_ekrani.dart';
import '../online/hata_raporu.dart';
import '../online/auth_ekrani.dart';
import '../online/online_servis.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'arkadasla_ekrani.dart';
import 'cuzdan_ekrani.dart';
import 'ligler_ekrani.dart';

const ligAdlari = {
  'amator': 'AMATÖR',
  'lig3': '3. LİG',
  'lig2': '2. LİG',
  'lig1': '1. LİG',
  'super': 'SÜPER LİG',
  'avrupa': 'AVRUPA LİGİ',
  'sampiyonlar': 'ŞAMPİYONLAR LİGİ',
};
const sonrakiLig = {
  'amator': '3. Lig',
  'lig3': '2. Lig',
  'lig2': '1. Lig',
  'lig1': 'Süper Lig',
  'super': 'Avrupa Ligi',
  'avrupa': 'Şampiyonlar Ligi',
};

/// EKRAN 1 · LOBİ — golriva_ekranlar_v1.html'e birebir:
/// marka + avatar, selamlama, lig ilerlemesi, ELO/GALİBİYET/RIVA,
/// HIZLI DÜELLO, BO3 SERİ / ARKADAŞLA, MASALAR, reklam kartı.
class OynaSekmesi extends StatefulWidget {
  final GolrivaRepos repos;
  final VoidCallback? onProfil; // sag ust avatar → PROFİL sekmesi
  final VoidCallback? onMagaza; // reklam karti → MAĞAZA sekmesi
  const OynaSekmesi(
      {super.key, required this.repos, this.onProfil, this.onMagaza});

  @override
  State<OynaSekmesi> createState() => _OynaSekmesiState();
}

class _OynaSekmesiState extends State<OynaSekmesi> {
  final servis = OnlineServis();
  OnlineProfil? profil;
  int? galibiyet;
  List<Masa> masalar = [];
  String seciliMasa = 'klasik';

  bool yukleniyor = true; // ilk veri gelene kadar sayfa örtülü

  @override
  void initState() {
    super.initState();
    _yenile().whenComplete(() {
      if (mounted && yukleniyor) setState(() => yukleniyor = false);
    });
  }

  Future<void> _yenile() async {
    if (!SupabaseAyar.yapilandirildi) return;
    try {
      await servis.terkEdilmisleriKapat();
      final p = await servis.profilGetir();
      final m = await servis.masalar();
      int? g;
      if (p != null) {
        final ist = await servis.istatistik();
        g = ist.seri == 0 ? null : ist.galibiyet;
      }
      if (mounted) {
        setState(() {
          profil = p;
          masalar = m;
          galibiyet = g;
        });
      }
    } catch (e, s) {
      hataBildir('oyna._yenile', e, s);
    }
  }

  Masa? get _seciliMasaBilgi {
    for (final m in masalar) {
      if (m.kod == seciliMasa) return m;
    }
    return null;
  }

  /// Fiyat gösterimi için: sunucu listesi henüz gelmediyse varsayılanlar.
  /// (Kullanıcı geri bildirimi: "klasik 100 yazıyor ama BO3 250 istiyor" —
  /// iki modun ücreti de HER YERDE açıkça yazılır, sürpriz kalmaz.)
  Masa? get _fiyatMasasi {
    for (final m in (masalar.isEmpty ? _varsayilanMasalar : masalar)) {
      if (m.kod == seciliMasa) return m;
    }
    return null;
  }

  bool _kilitli(Masa m, String mod) {
    if (profil == null) return false;
    final giris = mod == 'bo3' ? m.girisBo3 : m.giris;
    return profil!.bakiye < giris || profil!.bakiye < m.minBakiyeKilit;
  }

  Future<void> _duelloBaslat(String mod) async {
    if (!SupabaseAyar.yapilandirildi) {
      _uyari('Çevrimiçi mod için Supabase yapılandırması gerekli '
          '(README_SUPABASE.md).');
      return;
    }
    if (profil == null) {
      // Oturum yok ya da profil tamamlanmamış: uygulama ekranlarına dönüş
      // YOKTUR — giriş/kayıt kök olarak açılır (geri tuşu sekmelere getiremez;
      // AuthEkrani doğru adımı kendisi seçer).
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => AuthEkrani(repos: widget.repos)),
          (_) => false);
      return;
    }
    final m = _seciliMasaBilgi;
    if (m != null && _kilitli(m, mod)) {
      _kilitBilgi(m, mod);
      return;
    }
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AramaEkrani(
                repos: widget.repos, mod: mod, masaKod: seciliMasa)));
    _yenile();
  }

  void _uyari(String s) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(s)));

  void _kilitBilgi(Masa m, String mod) {
    final b = profil?.bakiye ?? 0;
    final giris = mod == 'bo3' ? m.girisBo3 : m.giris;
    final nedenler = <String>[];
    if (b < giris) {
      nedenler.add('Giriş ücreti $giris RIVA — bakiyen $b RIVA, yetmiyor.');
    }
    if (b < m.minBakiyeKilit) {
      nedenler.add('Bu masaya oturmak için en az ${m.minBakiyeKilit} RIVA '
          'bakiye gerekir (yüksek masalar deneyimli cüzdanlara açılır).');
    }
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: GolrivaColors.edge)),
        title: Text('${m.kod.toUpperCase()} MASASI KİLİTLİ',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1,
                color: GolrivaColors.ink)),
        content: Text(
            '${nedenler.join("\n\n")}\n\n'
            'RIVA kazanmak için alt masalarda maç kazanabilirsin.',
            style: GoogleFonts.figtree(
                fontSize: 13, color: GolrivaColors.dim, height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('ANLADIM',
                  style: TextStyle(color: GolrivaColors.goldHi))),
        ],
      ),
    );
  }

  String get _selam {
    final saat = DateTime.now().hour;
    if (saat < 6) return 'İyi geceler';
    if (saat < 12) return 'Günaydın';
    if (saat < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    final ad = profil?.kullaniciAdi ?? 'MİSAFİR';
    return YuklemeOrtusu(
      yukleniyor: yukleniyor,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        // marka + avatar
        Row(children: [
          SvgPicture.asset('assets/brand/beyin_top.svg', width: 30, height: 30),
          const SizedBox(width: 9),
          Row(children: [
            goldYazi('GOL', boyut: 25),
            Text('RIVA',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: GolrivaColors.ink)),
          ]),
          const Spacer(),
          // avatar → PROFİL sekmesi (kullanici istegi)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onProfil,
            child: avatar(ad, 36, url: profil?.avatarUrl),
          ),
        ]),
        const SizedBox(height: 13),
        // selamlama + lig ilerlemesi
        Text(_selam,
            style:
                GoogleFonts.figtree(fontSize: 12.5, color: GolrivaColors.dim)),
        Text(ad.toUpperCase(),
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
        if (profil != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            // lig hapı → LİGLER sayfası
            InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LiglerEkrani())),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x24D4AF37),
                  border: Border.all(color: GolrivaColors.edge),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(ligAdlari[profil!.ligKod] ?? profil!.ligKod,
                    style: GoogleFonts.bigShouldersDisplay(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: GolrivaColors.goldHi)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: ilerleme(profil!.ligPuan / 30)),
            const SizedBox(width: 8),
            Text('${profil!.ligPuan}/30',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, color: GolrivaColors.dim)),
            const SizedBox(width: 8),
            if (sonrakiLig[profil!.ligKod] != null)
              Flexible(
                child: Text("${sonrakiLig[profil!.ligKod]}'e yolculuk",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: GolrivaColors.dim2)),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        // ELO / GALIBIYET / RIVA
        Row(children: [
          _statKart('${profil?.elo ?? "—"}', 'ELO'),
          const SizedBox(width: 9),
          _statKart(galibiyet == null ? '—' : '%$galibiyet', 'GALİBİYET'),
          const SizedBox(width: 9),
          _statKart('${profil?.bakiye ?? "—"}', 'RIVA',
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CuzdanEkrani()))),
        ]),
        const SizedBox(height: 13),
        goldButon(
            'HIZLI DÜELLO · ${_fiyatMasasi?.giris ?? 100}',
            () => _duelloBaslat('bo1'),
            ikonAd: 'simsek'),
        const SizedBox(height: 9),
        Row(children: [
          Expanded(
              child: _ikincilButon(
                  'BO3 SERİ · ${_fiyatMasasi?.girisBo3 ?? 250}',
                  () => _duelloBaslat('bo3'),
                  altinKenar: true)),
          const SizedBox(width: 9),
          Expanded(
              child: _ikincilButon(
                  'ARKADAŞLA',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ArkadaslaEkrani(repos: widget.repos))))),
        ]),
        const SizedBox(height: 15),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('MASALAR',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              Text('${seciliMasa[0].toUpperCase()}${seciliMasa.substring(1)} seçili',
                  style: GoogleFonts.figtree(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.gold)),
            ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final m in (masalar.isEmpty ? _varsayilanMasalar : masalar)) ...[
            Expanded(child: _masaChip(m)),
            if (m != (masalar.isEmpty ? _varsayilanMasalar : masalar).last)
              const SizedBox(width: 7),
          ],
        ]),
        const SizedBox(height: 11),
        // reklam karti → MAĞAZA sekmesi (reklam izleme artik orada)
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.onMagaza,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: kartDekor(),
            child: Row(children: [
              gIkon('riva', 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Günün ilk reklamı hazır',
                    style: GoogleFonts.figtree(
                        fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
              Text('+50',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.ok)),
            ]),
          ),
        ),
      ],
    ),
    );
  }

  static final _varsayilanMasalar = [
    Masa('caylak', 50, 120, 0),
    Masa('klasik', 100, 250, 0),
    Masa('yuksek', 250, 600, 500),
    Masa('elit', 500, 1200, 1000),
  ];

  Widget _statKart(String deger, String ad, {VoidCallback? onTap}) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: kartDekor(),
            child: Column(children: [
              Text(deger,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.goldHi)),
              const SizedBox(height: 1),
              etiket(ad),
            ]),
          ),
        ),
      );

  Widget _ikincilButon(String s, VoidCallback onTap,
          {bool altinKenar = false}) =>
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: kartDekor().copyWith(
              border: Border.all(
                  color: altinKenar ? GolrivaColors.edge : GolrivaColors.edge2)),
          child: Text(s,
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: GolrivaColors.ink)),
        ),
      );

  Widget _masaChip(Masa m) {
    final secili = m.kod == seciliMasa;
    final kilitli = _kilitli(m, 'bo1');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (kilitli) {
          _kilitBilgi(m, 'bo1');
        } else {
          setState(() => seciliMasa = m.kod);
        }
      },
      child: Opacity(
        opacity: kilitli ? .35 : (secili ? 1 : .6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: secili ? gKartDekor() : kartDekor(),
          child: Column(children: [
            // FittedBox: dar ekranda chip adi + kilit ikonu kucularek sigar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(m.kod.toUpperCase(),
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: secili
                              ? GolrivaColors.goldHi
                              : GolrivaColors.ink)),
                  if (kilitli) ...[
                    const SizedBox(width: 3),
                    gIkon('kilit', 11, GolrivaColors.dim2),
                  ],
                ]),
              ),
            ),
            // iki modun ücreti de görünür: "tek / bo3"
            Text('${m.giris} / ${m.girisBo3}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10.5,
                    color: secili ? GolrivaColors.gold : GolrivaColors.dim)),
          ]),
        ),
      ),
    );
  }
}
