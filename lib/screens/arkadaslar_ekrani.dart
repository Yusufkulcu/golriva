import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../online/davet_ekrani.dart';
import '../online/hata_raporu.dart';
import '../online/online_servis.dart';
import '../online/oyun_yonlendirici.dart';
import '../online/supabase_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'oyna_sekmesi.dart' show ligAdlari;

/// ARKADAŞLAR — kullanıcı adıyla ekleme (karşılıklı, onaysız MVP),
/// liste (ad · elo · lig), çıkarma, DOĞRUDAN DÜELLO İSTEĞİ ve
/// GELEN DAVETLER (arkadaşın kurduğu hedefli davetler; 5 sn'de bir tazelenir).
class ArkadaslarEkrani extends StatefulWidget {
  final GolrivaRepos repos;
  const ArkadaslarEkrani({super.key, required this.repos});

  @override
  State<ArkadaslarEkrani> createState() => _ArkadaslarEkraniState();
}

class _ArkadaslarEkraniState extends State<ArkadaslarEkrani> {
  final servis = OnlineServis();
  final denetleyici = TextEditingController();
  List<({String ad, int elo, String ligKod})>? liste;
  List<({String kod, String kurucuAd, String mod, DateTime tarih})> gelenler =
      [];
  List<({String ad, DateTime tarih})> istekler = [];
  String? hata;
  bool ekleniyor = false;
  bool katiliniyor = false;
  Timer? davetNabzi;

  @override
  void initState() {
    super.initState();
    _yukle();
    _gelenleriYukle();
    davetNabzi =
        Timer.periodic(const Duration(seconds: 5), (_) => _gelenleriYukle());
  }

  @override
  void dispose() {
    davetNabzi?.cancel();
    denetleyici.dispose();
    super.dispose();
  }

  Future<void> _gelenleriYukle() async {
    if (!SupabaseAyar.yapilandirildi || !servis.girisYapildi) return;
    try {
      final g = await servis.gelenDavetler();
      if (mounted) setState(() => gelenler = g);
    } catch (_) {} // sessiz: sonraki yoklama telafi eder
    try {
      final i = await servis.gelenArkadasIstekleri();
      if (mounted) setState(() => istekler = i);
    } catch (_) {}
  }

  /// Arkadaşlık isteğine yanıt (kullanıcı kuralı: onaysız arkadaşlık yok).
  Future<void> _istekYanit(String ad, bool kabul) async {
    try {
      await servis.arkadasIstekYanit(ad, kabul);
      await _gelenleriYukle();
      if (kabul) await _yukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(kabul
                ? '$ad ile artık arkadaşsınız'
                : '$ad isteği silindi')));
      }
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(temizMesaj('arkadaslar._istekYanit', e,
                'Şu an yanıtlanamadı — tekrar dene.', s))));
      }
    }
  }

  /// Gelen daveti kabul et → dostluk serisi kurulur, maça geçilir.
  Future<void> _kabul(String kod) async {
    if (katiliniyor) return;
    setState(() => katiliniyor = true);
    try {
      final bilgi = await servis.davetKatil(kod);
      if (bilgi == null) throw 'seri bulunamadı';
      if (!mounted) return;
      davetNabzi?.cancel();
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => onlineOyunEkrani(widget.repos, bilgi)));
    } catch (e, s) {
      if (mounted) {
        setState(() => katiliniyor = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.contains('bulunamadı')
                ? 'Davetin süresi dolmuş ya da iptal edilmiş.'
                : temizMesaj('arkadaslar._kabul', e,
                    'Katılım şu an gerçekleşemedi — tekrar dene.', s))));
        _gelenleriYukle();
      }
    }
  }

  /// Arkadaşa doğrudan düello isteği: davet kur ekranı hedefli açılır.
  void _duelloIstegi(String ad) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                DavetKurEkrani(repos: widget.repos, hedefAd: ad)));
  }

  Future<void> _yukle() async {
    if (!SupabaseAyar.yapilandirildi || !servis.girisYapildi) {
      setState(() => hata = 'Arkadaş listesi için çevrimiçi hesap gerekli.');
      return;
    }
    try {
      final l = await servis.arkadasListesi();
      if (mounted) setState(() => liste = l);
    } catch (e, s) {
      if (mounted) {
        setState(() => hata = temizMesaj('arkadaslar._yukle', e,
            'Liste şu an yüklenemedi — tekrar dene.', s));
      }
    }
  }

  Future<void> _ekle() async {
    final ad = denetleyici.text.trim();
    if (ad.isEmpty) return;
    setState(() => ekleniyor = true);
    try {
      final sonuc = await servis.arkadasEkle(ad);
      denetleyici.clear();
      await _yukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(sonuc == 'arkadas'
                ? '$ad ile artık arkadaşsınız'
                : '$ad kullanıcısına arkadaşlık isteği gönderildi — '
                    'onaylayınca listende görünecek')));
      }
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.contains('bulunamadı')
                ? 'Kullanıcı bulunamadı — adı kontrol et.'
                : '$e'.contains('kendini')
                    ? 'Kendini ekleyemezsin :)'
                    : temizMesaj('arkadaslar._ekle', e,
                        'Şu an eklenemedi — tekrar dene.', s))));
      }
    } finally {
      if (mounted) setState(() => ekleniyor = false);
    }
  }

  Future<void> _sil(String ad) async {
    try {
      await servis.arkadasSil(ad);
      await _yukle();
    } catch (e, s) {
      hataBildir('arkadaslar._sil', e, s);
    }
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
            // ARKADAŞLIK İSTEKLERİ — onay bekleyenler (kullanıcı kuralı)
            if (istekler.isNotEmpty) ...[
              etiket('ARKADAŞLIK İSTEKLERİ', renk: GolrivaColors.goldHi),
              const SizedBox(height: 7),
              for (final i in istekler)
                Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: gKartDekor(),
                  child: Row(children: [
                    avatar(i.ad, 36, kenar: GolrivaColors.gold),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text('${i.ad} seni arkadaş olarak eklemek istiyor',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: GoogleFonts.figtree(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: GolrivaColors.gold,
                          foregroundColor: const Color(0xFF231A04),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8)),
                      onPressed: () => _istekYanit(i.ad, true),
                      child: Text('ONAYLA',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 13)),
                    ),
                    IconButton(
                      onPressed: () => _istekYanit(i.ad, false),
                      icon: gIkon('carpi', 14, GolrivaColors.dim2),
                      tooltip: 'Reddet',
                    ),
                  ]),
                ),
              const SizedBox(height: 7),
            ],
            // GELEN DAVETLER — arkadaşların kurduğu hedefli düello istekleri
            if (gelenler.isNotEmpty) ...[
              etiket('GELEN DAVETLER', renk: GolrivaColors.goldHi),
              const SizedBox(height: 7),
              for (final g in gelenler)
                Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: gKartDekor(),
                  child: Row(children: [
                    avatar(g.kurucuAd, 36, kenar: GolrivaColors.gold),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${g.kurucuAd} seni düelloya çağırıyor',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.figtree(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            Text(
                                '${g.mod == "bo3" ? "3 MAÇLIK SERİ" : "TEK MAÇ"} · dostluk',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10, color: GolrivaColors.dim)),
                          ]),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: GolrivaColors.gold,
                          foregroundColor: const Color(0xFF231A04),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8)),
                      onPressed:
                          katiliniyor ? null : () => _kabul(g.kod),
                      child: Text(katiliniyor ? '…' : 'KABUL',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14)),
                    ),
                  ]),
                ),
              const SizedBox(height: 7),
            ],
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
          // DOĞRUDAN DÜELLO İSTEĞİ (kullanıcı isteği: kod paylaşmadan)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: GolrivaColors.goldHi,
                side: const BorderSide(color: GolrivaColors.goldDeep),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            onPressed: () => _duelloIstegi(a.ad),
            child: Text('DÜELLO',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontSize: 13)),
          ),
          IconButton(
            onPressed: () => _sil(a.ad),
            icon: gIkon('carpi', 14, GolrivaColors.dim2),
            tooltip: 'Listeden çıkar',
          ),
        ]),
      );
}
