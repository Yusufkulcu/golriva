import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../online/bildirim_servis.dart';
import '../online/oturum_bekcisi.dart';
import '../online/hata_raporu.dart';
import '../data/repos.dart';
import '../main.dart' show navigatorKey;
import '../online/auth_ekrani.dart';
import '../online/online_servis.dart';
import '../online/oyun_yonlendirici.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'kilavuz_ekrani.dart';
import 'ligler_ekrani.dart';
import 'oyna_sekmesi.dart';

const _aylar = [
  '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
];

/// EKRAN 10 · PROFİL — avatar, kimlik, ELO/SERİ/GALİBİYET, lig kartı,
/// oyun performansı, rozetler.
class ProfilSekmesi extends StatefulWidget {
  final GolrivaRepos repos;
  const ProfilSekmesi({super.key, required this.repos});

  @override
  State<ProfilSekmesi> createState() => _ProfilSekmesiState();
}

class _ProfilSekmesiState extends State<ProfilSekmesi> {
  OnlineProfil? profil;
  int? siram;
  ({int seri, int galibiyet, Map<String, (int, int)> oyunlar})? ist;
  List<({String rakip, int s1, int s2, bool? kazandim, String mod,
      DateTime tarih, bool benP1})>? duellolar;
  bool yuklendi = false;
  bool fotoYukleniyor = false;

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
      List<({String rakip, int s1, int s2, bool? kazandim, String mod,
          DateTime tarih, bool benP1})>? d;
      if (p != null) {
        i = await servis.istatistik();
        final (_, s) = await servis.siralama();
        sira = s;
        d = await servis.macGecmisi();
      }
      if (mounted) {
        setState(() {
          profil = p;
          ist = i;
          siram = sira;
          duellolar = d;
          yuklendi = true;
        });
      }
    } catch (e, s) {
      hataBildir('profil._yukle', e, s);
      if (mounted) setState(() => yuklendi = true);
    }
  }

  /// PROFİL FOTOĞRAFI: galeriden sec → kucult → Storage'a yukle.
  Future<void> _fotoSec() async {
    if (fotoYukleniyor) return;
    try {
      final secim = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 82);
      if (secim == null) return;
      setState(() => fotoYukleniyor = true);
      final bytes = await secim.readAsBytes();
      await OnlineServis().avatarYukle(bytes);
      await _yukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil fotoğrafın güncellendi')));
      }
    } catch (e, s) {
      if (mounted) {
        // Teknik ayrinti (bucket/403/policy vb.) admin paneline raporlanir;
        // kullanici yalnizca sade bir mesaj gorur.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(temizMesaj('profil._fotoSec', e,
                'Fotoğraf yüklenemedi — tekrar dene.', s))));
      }
    } finally {
      if (mounted) setState(() => fotoYukleniyor = false);
    }
  }

  Future<void> _cikis() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        title: Text('Çıkış yap?',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, color: GolrivaColors.ink)),
        content: Text(
            OnlineServis().misafirMi
                ? 'DİKKAT: misafir hesabı bu cihaza bağlı — çıkarsan bu '
                    'hesaba bir daha ULAŞAMAZSIN. Emin misin?'
                : 'Tekrar e-posta ve şifrenle girebilirsin.',
            style: GoogleFonts.figtree(color: GolrivaColors.dim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('VAZGEÇ')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('ÇIKIŞ YAP',
                  style: TextStyle(color: GolrivaColors.bad))),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    OturumBekcisi().durdur();
    try {
      await BildirimServis.cikistaTemizle(); // bu cihaza artık bildirim gitmesin
    } catch (e, s) {
      hataBildir('profil.cikisBildirim', e, s); // çıkışı asla engellemez
    }
    try {
      await OnlineServis().cikisYap();
    } catch (e, s) {
      hataBildir('profil.cikis', e, s);
    }
    // Girişe dönüş asıl olarak main'deki merkezi cikisiDinle dinleyicisiyle
    // olur; bu satır yalnız emniyettir (çift çağrı zararsız — kök tekildir).
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (!yuklendi) {
      return const Center(
          child: CircularProgressIndicator(color: GolrivaColors.gold));
    }
    if (profil == null) return _hesapYok();
    final p = profil!;
    final servis = OnlineServis();
    final kimlik = [
      if (p.uyelik != null)
        'Üyelik: ${_aylar[p.uyelik!.month]} ${p.uyelik!.year}',
      servis.misafirMi ? 'Misafir hesabı' : (servis.eposta ?? ''),
    ].where((s) => s.isNotEmpty).join(' · ');
    return RefreshIndicator(
      color: GolrivaColors.gold,
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          // avatar: dokun → galeriden fotograf sec (kullanici istegi)
          Center(
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _fotoSec,
              child: Stack(alignment: Alignment.bottomRight, children: [
                avatar(p.kullaniciAdi, 76,
                    kenar: GolrivaColors.gold,
                    kalinlik: 2.5,
                    url: p.avatarUrl),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GolrivaColors.card2,
                      border: Border.all(color: GolrivaColors.edge)),
                  child: fotoYukleniyor
                      ? const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                              color: GolrivaColors.gold, strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined,
                          size: 13, color: GolrivaColors.goldHi),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(p.kullaniciAdi.toUpperCase(),
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1)),
          ),
          Center(
            child: Text(kimlik,
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
          // ── SON DÜELLOLAR (menuden kaldirildi, buraya tasindi) ──
          const SizedBox(height: 13),
          Text('SON DÜELLOLAR',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          if (duellolar == null || duellolar!.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: kartDekor(),
              child: Text(
                  'Henüz biten düello yok — OYNA sekmesinden HIZLI DÜELLO ile başla!',
                  style: GoogleFonts.figtree(
                      fontSize: 12, color: GolrivaColors.dim)),
            )
          else
            for (final m in duellolar!) _duelloKarti(m),
          // ── KILAVUZ + ÇIKIŞ ──
          const SizedBox(height: 13),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const KilavuzEkrani())),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: kartDekor(r: 14),
              child: Row(children: [
                gIkon('rulet', 16, GolrivaColors.gold),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('Nasıl çalışır? — Elo, Riva, ligler · KILAVUZ',
                      style: GoogleFonts.figtree(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                Text('›',
                    style: GoogleFonts.figtree(
                        fontSize: 16, color: GolrivaColors.dim2)),
              ]),
            ),
          ),
          if (OnlineServis().girisYapildi) ...[
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _cikis,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: kartDekor(r: 14),
                child: Row(children: [
                  gIkon('carpi', 15, GolrivaColors.bad),
                  const SizedBox(width: 9),
                  Text('Çıkış yap',
                      style: GoogleFonts.figtree(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GolrivaColors.bad)),
                ]),
              ),
            ),
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _hesabiSil,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: kartDekor(r: 14),
                child: Row(children: [
                  gIkon('carpi', 15, GolrivaColors.dim2),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text('Hesabımı sil',
                        style: GoogleFonts.figtree(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: GolrivaColors.dim)),
                  ),
                  Text('kalıcı',
                      style: GoogleFonts.figtree(
                          fontSize: 10, color: GolrivaColors.dim2)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// HESABIMI SİL — çift onaylı, geri alınamaz. Tüm veriler silinir.
  Future<void> _hesabiSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        title: Text('Hesabımı sil?',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, color: GolrivaColors.bad)),
        content: Text(
            'Bu işlem GERİ ALINAMAZ. Profilin, Riva bakiyen, maç geçmişin, '
            'arkadaşların ve tüm verilerin kalıcı olarak silinir.',
            style: GoogleFonts.figtree(color: GolrivaColors.dim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('VAZGEÇ')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('SİL',
                  style: TextStyle(color: GolrivaColors.bad))),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: GolrivaColors.gold)),
    );
    try {
      OturumBekcisi().durdur();
      await BildirimServis.cikistaTemizle();
      await OnlineServis().hesabimiSil();
      if (!mounted) return;
      Navigator.of(context).pop(); // yükleniyor diyaloğu
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e, s) {
      if (mounted) Navigator.of(context).pop(); // yükleniyor diyaloğu
      hataBildir('profil._hesabiSil', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Hesap şu an silinemedi — tekrar dene.')));
      }
    }
  }

  Widget _duelloKarti(
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: (m.kazandim ?? false) ? gKartDekor() : kartDekor(),
      child: Row(children: [
        avatar(m.rakip, 34, kenar: GolrivaColors.p2),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.rakip,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            Text(
                '${m.mod.toUpperCase()} · ${m.tarih.day} ${_aylar[m.tarih.month]}',
                style: GoogleFonts.figtree(
                    fontSize: 9.5, color: GolrivaColors.dim)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$skorum - $skorRakip',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.goldHi)),
          Text(durum,
              style: GoogleFonts.figtree(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: renk)),
        ]),
      ]),
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
                child: goldButon('HESAP AÇ · +500 RIVA', () {
                  // Geri dönüş YOK: giriş/kayıt kök olarak açılır.
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => AuthEkrani(repos: widget.repos)),
                      (_) => false);
                }, yazi: 15),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const KilavuzEkrani())),
              child: const Text('Nasıl çalışır? · KILAVUZ',
                  style:
                      TextStyle(color: GolrivaColors.goldHi, fontSize: 12)),
            ),
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
