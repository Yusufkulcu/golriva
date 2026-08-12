import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../online/alig_servis.dart';
import '../online/hata_raporu.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'alig_detay_ekrani.dart';

/// ARKADAŞ LİGİ (Faz 2.19) — lig listesi + kur + kodla katıl.
/// Kurucu katılım ücretini (0 = ücretsiz) ve süreyi belirler; lig dolunca
/// fikstür otomatik çekilir; şampiyon havuzun %80'ini alır.
class ArkadasLigiEkrani extends StatefulWidget {
  final GolrivaRepos repos;
  const ArkadasLigiEkrani({super.key, required this.repos});

  @override
  State<ArkadasLigiEkrani> createState() => _ArkadasLigiEkraniState();
}

class _ArkadasLigiEkraniState extends State<ArkadasLigiEkrani> {
  final servis = AligServis();
  List<AligOzet>? ligler;
  String? hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final r = await servis.liglerim();
      if (mounted) setState(() => ligler = r);
    } catch (e, s) {
      if (mounted) {
        setState(() => hata = temizMesaj('alig.liste', e,
            'Ligler yüklenemedi — tekrar dene.', s));
      }
    }
  }

  Future<void> _detayaGit(String ligId) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AligDetayEkrani(repos: widget.repos, ligId: ligId)));
    _yukle();
  }

  // ---------- LİG KUR ----------
  Future<void> _ligKur() async {
    final adCtrl = TextEditingController();
    var giris = 500;
    var boyut = 4;
    var sure = 7;
    var kuruluyor = false;
    final kod = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: GolrivaColors.card,
          title: Text('LİG KUR',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, color: GolrivaColors.ink)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: adCtrl,
                maxLength: 24,
                decoration:
                    const InputDecoration(hintText: 'Lig adı (3-24 harf)'),
              ),
              const SizedBox(height: 6),
              _secimSatiri<int>(
                  baslik: 'KATILIM (HERKES EŞİT ÖDER)',
                  secenekler: const [0, 100, 250, 500, 1000, 2500],
                  etiketle: (v) => v == 0 ? 'ÜCRETSİZ' : '$v',
                  secili: giris,
                  onSec: (v) => setD(() => giris = v)),
              const SizedBox(height: 10),
              _secimSatiri<int>(
                  baslik: 'LİG BOYUTU',
                  secenekler: const [4, 6, 8],
                  etiketle: (v) => '$v KİŞİ',
                  secili: boyut,
                  onSec: (v) => setD(() => boyut = v)),
              const SizedBox(height: 10),
              _secimSatiri<int>(
                  baslik: 'LİG SÜRESİ',
                  secenekler: const [3, 7, 14, 30],
                  etiketle: (v) => '$v GÜN',
                  secili: sure,
                  onSec: (v) => setD(() => sure = v)),
              const SizedBox(height: 8),
              Text(
                  'Şampiyon havuzun %80\'ini alır. Lig dolunca fikstür '
                  'otomatik çekilir; 48 saatte dolmazsa iptal edilir ve '
                  'katılımlar iade edilir.',
                  style: GoogleFonts.figtree(
                      fontSize: 10.5, color: GolrivaColors.dim)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('VAZGEÇ')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: GolrivaColors.gold,
                  foregroundColor: const Color(0xFF231A04)),
              onPressed: kuruluyor
                  ? null
                  : () async {
                      setD(() => kuruluyor = true);
                      try {
                        final k = await servis.ligOlustur(
                            ad: adCtrl.text.trim(),
                            giris: giris,
                            boyut: boyut,
                            sureGun: sure);
                        if (c.mounted) Navigator.pop(c, k);
                      } catch (e, s) {
                        setD(() => kuruluyor = false);
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                              content: Text(temizMesaj(
                                  'alig.kur',
                                  e,
                                  'Lig kurulamadı — bilgileri kontrol et.',
                                  s))));
                        }
                      }
                    },
              child: Text(kuruluyor ? 'KURULUYOR…' : 'KUR'),
            ),
          ],
        ),
      ),
    );
    if (kod != null && mounted) {
      await _yukle();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: GolrivaColors.card,
          title: Text('LİG KURULDU',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, color: GolrivaColors.goldHi)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Arkadaşlarına bu kodu gönder:',
                style: GoogleFonts.figtree(
                    fontSize: 12, color: GolrivaColors.dim)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: kod));
                ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(content: Text('Kod kopyalandı')));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GolrivaColors.goldDeep)),
                child: Text(kod,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: GolrivaColors.goldHi)),
              ),
            ),
            const SizedBox(height: 6),
            Text('(dokun = kopyala)',
                style: GoogleFonts.figtree(
                    fontSize: 10, color: GolrivaColors.dim2)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('TAMAM')),
          ],
        ),
      );
    }
  }

  // ---------- KODLA KATIL ----------
  Future<void> _katil() async {
    final kodCtrl = TextEditingController();
    var oluyor = false;
    final oldu = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          backgroundColor: GolrivaColors.card,
          title: Text('LİGE KATIL',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, color: GolrivaColors.ink)),
          content: TextField(
            controller: kodCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'LIG-XXXX'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('VAZGEÇ')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: GolrivaColors.gold,
                  foregroundColor: const Color(0xFF231A04)),
              onPressed: oluyor
                  ? null
                  : () async {
                      setD(() => oluyor = true);
                      try {
                        await servis.ligKatil(kodCtrl.text);
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e, s) {
                        setD(() => oluyor = false);
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                              content: Text(temizMesaj(
                                  'alig.katil',
                                  e,
                                  'Katılamadın — kodu ve bakiyeni kontrol et.',
                                  s))));
                        }
                      }
                    },
              child: Text(oluyor ? 'KATILINIYOR…' : 'KATIL'),
            ),
          ],
        ),
      ),
    );
    if (oldu == true) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final liste = ligler;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text('ARKADAŞ LİGİ',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text('HAVUZLU ŞAMPİYONLUK · %80 ŞAMPİYONA',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 9.5,
                  color: GolrivaColors.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2)),
        ]),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: GolrivaColors.gold,
          onRefresh: _yukle,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              Row(children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _ligKur,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          gradient: GolrivaColors.goldGradient,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('LİG KUR',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: const Color(0xFF231A04))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _katil,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: kartDekor(r: 12).copyWith(
                          border: Border.all(color: GolrivaColors.edge)),
                      child: Text('KODLA KATIL',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: GolrivaColors.goldHi)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              etiket('LİGLERİM'),
              const SizedBox(height: 6),
              if (hata != null)
                Text(hata!,
                    style: GoogleFonts.figtree(
                        fontSize: 12, color: GolrivaColors.bad))
              else if (liste == null)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: GolrivaColors.gold, strokeWidth: 2.5)),
                )
              else if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Text(
                      'Henüz bir ligin yok. Lig kur, kodu arkadaşlarına '
                      'gönder — lig dolunca fikstür otomatik çekilir.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 12, color: GolrivaColors.dim)),
                )
              else
                for (final l in liste) _ligKart(l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ligKart(AligOzet l) {
    final (durumYazi, durumRenk) = switch (l.durum) {
      'acik' => ('${l.uyeSayisi}/${l.boyut} · OYUNCU BEKLİYOR', GolrivaColors.gold),
      'aktif' => ('DEVAM EDİYOR', GolrivaColors.ok),
      'bitti' => ('BİTTİ', GolrivaColors.dim),
      _ => ('İPTAL — katılımlar iade edildi', GolrivaColors.bad),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _detayaGit(l.id),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: kartDekor(r: 16),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5)),
                    const SizedBox(height: 2),
                    Text(durumYazi,
                        style: GoogleFonts.figtree(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: durumRenk)),
                  ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(l.giris == 0 ? 'ÜCRETSİZ' : 'HAVUZ ${l.havuz}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: GolrivaColors.goldHi)),
              if (l.durum == 'aktif')
                Text('${l.benimPuan} puan',
                    style: GoogleFonts.figtree(
                        fontSize: 10, color: GolrivaColors.dim)),
            ]),
            const SizedBox(width: 6),
            Text('›',
                style: GoogleFonts.figtree(
                    fontSize: 18, color: GolrivaColors.dim2)),
          ]),
        ),
      ),
    );
  }

  Widget _secimSatiri<T>(
      {required String baslik,
      required List<T> secenekler,
      required String Function(T) etiketle,
      required T secili,
      required void Function(T) onSec}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      etiket(baslik),
      const SizedBox(height: 5),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in secenekler)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSec(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: s == secili
                      ? const Color(0x33D4AF37)
                      : GolrivaColors.card2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: s == secili
                          ? GolrivaColors.gold
                          : GolrivaColors.edge2),
                ),
                child: Text(etiketle(s),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: s == secili
                            ? GolrivaColors.goldHi
                            : GolrivaColors.dim)),
              ),
            ),
        ],
      ),
    ]);
  }
}
