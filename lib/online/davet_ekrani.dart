import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'online_servis.dart';
import 'oyun_yonlendirici.dart';

/// DAVET KUR — arkadasini uzaktan dostluk macina cagir:
/// 1) oyun (RULET ya da sabit) + mod sec, 2) GLR-XXXX kodu paylas,
/// 3) arkadas koda katilinca iki taraf da otomatik maca alinir.
/// Dostluk maci: Riva ALINMAZ, Elo ISLEMEZ (sunucu kurali).
class DavetKurEkrani extends StatefulWidget {
  final GolrivaRepos repos;
  const DavetKurEkrani({super.key, required this.repos});

  @override
  State<DavetKurEkrani> createState() => _DavetKurEkraniState();
}

class _DavetKurEkraniState extends State<DavetKurEkrani> {
  final servis = OnlineServis();
  String? oyunKodu; // null = rulet
  String mod = 'bo1';
  String? kod; // olusturulunca dolar → bekleme adimi
  String? hata;
  bool kuruluyor = false;
  Timer? nabiz;

  Future<void> _kur() async {
    setState(() {
      kuruluyor = true;
      hata = null;
    });
    try {
      final k = await servis.davetOlustur(mod, oyunKodu);
      if (!mounted) return;
      setState(() {
        kod = k;
        kuruluyor = false;
      });
      nabiz = Timer.periodic(const Duration(seconds: 2), (_) => _yokla());
    } catch (e) {
      if (mounted) {
        setState(() {
          kuruluyor = false;
          hata = 'Davet kurulamadı: $e';
        });
      }
    }
  }

  Future<void> _yokla() async {
    if (kod == null || !mounted) return;
    try {
      final bilgi = await servis.davetDurum(kod!);
      if (bilgi != null && mounted) {
        nabiz?.cancel();
        kod = null; // eslesti — dispose'da iptal edilmesin
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => onlineOyunEkrani(widget.repos, bilgi)));
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    nabiz?.cancel();
    if (kod != null) servis.davetIptal().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('DAVET KUR',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: kod == null ? _secimAdimi() : _beklemeAdimi(),
      ),
    );
  }

  // ── ADIM 1: OYUN + MOD SECIMI ──
  Widget _secimAdimi() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      children: [
        Text('DOSTLUK MAÇI · RIVA VE ELO İŞLEMEZ',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
                fontSize: 9.5,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.gold)),
        const SizedBox(height: 14),
        Text('OYUN',
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 2.7,
          children: [
            _oyunKart(null, 'RULET', 'Rastgele seçsin'),
            for (final k in onlineOynanabilir)
              _oyunKart(k, onlineOyunAdlari[k] ?? k, ''),
          ],
        ),
        const SizedBox(height: 14),
        Text('SERİ',
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _modKart('bo1', 'TEK MAÇ')),
          const SizedBox(width: 8),
          Expanded(child: _modKart('bo3', '3 MAÇLIK SERİ')),
        ]),
        if (hata != null) ...[
          const SizedBox(height: 10),
          Text(hata!,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.figtree(fontSize: 12, color: GolrivaColors.bad)),
        ],
        const SizedBox(height: 16),
        goldButon(kuruluyor ? 'KURULUYOR…' : 'DAVET KODU OLUŞTUR',
            kuruluyor ? null : _kur,
            yazi: 16),
      ],
    );
  }

  Widget _oyunKart(String? k, String ad, String alt) {
    final secili = oyunKodu == k;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => oyunKodu = k),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: secili ? gKartDekor(r: 14) : kartDekor(r: 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                if (k == null) ...[
                  gIkon('rulet', 12,
                      secili ? GolrivaColors.goldHi : GolrivaColors.dim),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                          color: secili
                              ? GolrivaColors.goldHi
                              : GolrivaColors.ink)),
                ),
              ]),
              if (alt.isNotEmpty)
                Text(alt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.figtree(
                        fontSize: 9, color: GolrivaColors.dim)),
            ]),
      ),
    );
  }

  Widget _modKart(String m, String ad) {
    final secili = mod == m;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => mod = m),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: secili ? gKartDekor(r: 14) : kartDekor(r: 14),
        child: Text(ad,
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: secili ? GolrivaColors.goldHi : GolrivaColors.ink)),
      ),
    );
  }

  // ── ADIM 2: KOD PAYLAS + BEKLE ──
  Widget _beklemeAdimi() {
    return Center(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: gKartDekor(r: 24),
            child: Column(children: [
              etiket('DAVET KODUN'),
              const SizedBox(height: 6),
              Text(kod ?? '',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                      color: GolrivaColors.goldHi)),
              const SizedBox(height: 12),
              goldButon('KOPYALA', () {
                Clipboard.setData(ClipboardData(text: kod ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kod panoya kopyalandı')));
              }, yazi: 14),
              const SizedBox(height: 18),
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: GolrivaColors.gold, strokeWidth: 2.5)),
              const SizedBox(height: 8),
              Text('Arkadaşın bekleniyor…',
                  style: GoogleFonts.figtree(
                      fontSize: 12, color: GolrivaColors.dim)),
              const SizedBox(height: 4),
              Text(
                  'Kodu gönder — o katılınca ikiniz de otomatik maça alınırsınız. '
                  'Kod 30 dakika geçerli.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                      fontSize: 10.5, color: GolrivaColors.dim2)),
            ]),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: GolrivaColors.dim,
                  side: const BorderSide(color: GolrivaColors.edge2)),
              onPressed: () => Navigator.pop(context),
              child: Text('VAZGEÇ',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontWeight: FontWeight.w800, letterSpacing: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// KODLA KATIL diyalogu — kod girilir, dogruysa maca gecilir.
Future<void> davetKatilDialog(BuildContext context, GolrivaRepos repos) async {
  final denetleyici = TextEditingController();
  String? hata;
  bool deneniyor = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: GolrivaColors.edge)),
        title: Text('KODLA KATIL',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.5,
                color: GolrivaColors.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: denetleyici,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, letterSpacing: 3, color: GolrivaColors.ink),
            decoration: const InputDecoration(hintText: 'GLR-XXXX'),
          ),
          if (hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(hata!,
                  style: GoogleFonts.figtree(
                      fontSize: 11.5, color: GolrivaColors.bad)),
            ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('VAZGEÇ')),
          TextButton(
            onPressed: deneniyor
                ? null
                : () async {
                    setD(() {
                      deneniyor = true;
                      hata = null;
                    });
                    try {
                      final bilgi =
                          await OnlineServis().davetKatil(denetleyici.text);
                      if (bilgi == null) throw 'seri bulunamadı';
                      if (!c.mounted) return;
                      final nav = Navigator.of(c);
                      nav.pop(); // dialog
                      nav.push(MaterialPageRoute(
                          builder: (_) => onlineOyunEkrani(repos, bilgi)));
                    } catch (e) {
                      setD(() {
                        deneniyor = false;
                        hata = '$e'.contains('bulunamadı')
                            ? 'Davet bulunamadı — kodu kontrol et '
                                '(süresi dolmuş olabilir).'
                            : 'Katılınamadı: $e';
                      });
                    }
                  },
            child: Text(deneniyor ? 'KATILINIYOR…' : 'KATIL',
                style: const TextStyle(color: GolrivaColors.goldHi)),
          ),
        ],
      ),
    ),
  );
}
