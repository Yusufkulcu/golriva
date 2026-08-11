import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'hata_raporu.dart';
import 'online_servis.dart';
import 'oyun_yonlendirici.dart';

/// DAVET KUR — arkadasini uzaktan dostluk macina cagir:
/// 1) oyun (RULET ya da sabit) + mod sec, 2) GLR-XXXX kodu paylas,
/// 3) arkadas koda katilinca iki taraf da otomatik maca alinir.
/// Dostluk maci: Riva ALINMAZ, Elo ISLEMEZ (sunucu kurali).
class DavetKurEkrani extends StatefulWidget {
  final GolrivaRepos repos;

  /// Dolu gelirse davet DOĞRUDAN bu arkadaşa kurulur: onun "gelen
  /// davetler" listesine düşer, kod paylaşmak gerekmez (yedek olarak durur).
  final String? hedefAd;
  const DavetKurEkrani({super.key, required this.repos, this.hedefAd});

  @override
  State<DavetKurEkrani> createState() => _DavetKurEkraniState();
}

class _DavetKurEkraniState extends State<DavetKurEkrani> {
  final servis = OnlineServis();
  String? oyunKodu; // bo1: null = rulet
  final List<String> secilenler = []; // bo3: SIRALI 3 oyun (boş = rulet)
  String mod = 'bo1';
  String? kod; // olusturulunca dolar → bekleme adimi
  String? hata;
  bool kuruluyor = false;
  Timer? nabiz;

  /// bo3'te kural: ya RULET (hiç seçim) ya TAM 3 oyun (kullanıcı isteği).
  bool get _kurulabilir =>
      mod == 'bo1' || secilenler.isEmpty || secilenler.length == 3;

  List<String>? get _oyunListesi => mod == 'bo1'
      ? (oyunKodu == null ? null : [oyunKodu!])
      : (secilenler.isEmpty ? null : List.of(secilenler));

  Future<void> _kur() async {
    setState(() {
      kuruluyor = true;
      hata = null;
    });
    try {
      final k = await servis.davetOlustur2(mod,
          oyunlar: _oyunListesi, hedefAd: widget.hedefAd);
      if (!mounted) return;
      setState(() {
        kod = k;
        kuruluyor = false;
      });
      nabiz = Timer.periodic(const Duration(seconds: 2), (_) => _yokla());
    } catch (e, s) {
      if (mounted) {
        setState(() {
          kuruluyor = false;
          hata = temizMesaj('davet._kur', e,
              'Davet şu an kurulamadı — tekrar dene.', s);
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
        if (widget.hedefAd != null) ...[
          Center(
            child: Text('RAKİP: ${widget.hedefAd}',
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: GolrivaColors.goldHi)),
          ),
          const SizedBox(height: 10),
        ],
        Text('SERİ',
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _modKart('bo1', 'TEK MAÇ')),
          const SizedBox(width: 8),
          Expanded(child: _modKart('bo3', '3 MAÇLIK SERİ')),
        ]),
        const SizedBox(height: 14),
        Text(mod == 'bo3' ? 'OYUNLAR — SIRAYLA 3 SEÇ (ya da RULET)' : 'OYUN',
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2)),
        if (mod == 'bo3')
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
                'Seçtiğin sıra maç sırasıdır · beraberlikte ek maçlar tekrarsız ruletten gelir',
                style: GoogleFonts.figtree(
                    fontSize: 10, color: GolrivaColors.dim2)),
          ),
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
        if (hata != null) ...[
          const SizedBox(height: 10),
          Text(hata!,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.figtree(fontSize: 12, color: GolrivaColors.bad)),
        ],
        const SizedBox(height: 16),
        goldButon(
            kuruluyor
                ? 'KURULUYOR…'
                : !_kurulabilir
                    ? '3 OYUN SEÇ (${secilenler.length}/3)'
                    : widget.hedefAd != null
                        ? 'DAVETİ GÖNDER'
                        : 'DAVET KODU OLUŞTUR',
            (kuruluyor || !_kurulabilir) ? null : _kur,
            yazi: 16),
      ],
    );
  }

  Widget _oyunKart(String? k, String ad, String alt) {
    final coklu = mod == 'bo3';
    final sira = (coklu && k != null) ? secilenler.indexOf(k) : -1;
    final secili = coklu
        ? (k == null ? secilenler.isEmpty : sira >= 0)
        : oyunKodu == k;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        if (!coklu) {
          oyunKodu = k;
          return;
        }
        // bo3: RULET = seçimleri temizle; oyun = sıralı seç/çıkar (en çok 3)
        if (k == null) {
          secilenler.clear();
        } else if (sira >= 0) {
          secilenler.remove(k);
        } else if (secilenler.length < 3) {
          secilenler.add(k);
        }
      }),
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
                if (sira >= 0) ...[
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: GolrivaColors.goldGradient),
                    child: Text('${sira + 1}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF231A04))),
                  ),
                  const SizedBox(width: 5),
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
              Text(
                  widget.hedefAd == null
                      ? 'Arkadaşın bekleniyor…'
                      : '${widget.hedefAd} bekleniyor…',
                  style: GoogleFonts.figtree(
                      fontSize: 12, color: GolrivaColors.dim)),
              const SizedBox(height: 4),
              Text(
                  widget.hedefAd == null
                      ? 'Kodu gönder — o katılınca ikiniz de otomatik maça '
                          'alınırsınız. Kod 30 dakika geçerli.'
                      : 'Davet ${widget.hedefAd} adlı arkadaşının GELEN '
                          'DAVETLER listesine düştü — kabul edince ikiniz de '
                          'otomatik maça alınırsınız. Kod yedek olarak '
                          'paylaşılabilir, 30 dakika geçerli.',
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
                    } catch (e, s) {
                      setD(() {
                        deneniyor = false;
                        hata = '$e'.contains('bulunamadı')
                            ? 'Davet bulunamadı — kodu kontrol et '
                                '(süresi dolmuş olabilir).'
                            : temizMesaj('davet._katil', e,
                                'Katılım şu an gerçekleşemedi — tekrar dene.',
                                s);
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
