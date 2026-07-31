import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/oyna_sekmesi.dart' show ligAdlari;
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'itiraz_dialog.dart';
import 'mac_kanali.dart';
import 'online_servis.dart';
import 'oyun_yonlendirici.dart' show onlineOyunAdlari;

/// EKRAN 8 · SERİ SONUCU — golriva_ekranlar_v1.html'e birebir:
/// marka 64, KAZANDIN!/KAYBETTİN/BERABERE, seri noktalari + skor,
/// ÖDÜL/ELO/GALİBİYET kartlari, oyunlarin ✓/✗ listesi, RÖVANŞ + PAYLAŞ.
class SeriSonucuEkrani extends StatefulWidget {
  final OnlineMacKanali kanal;
  final OnlineSeriDurumu durum;
  const SeriSonucuEkrani(
      {super.key, required this.kanal, required this.durum});

  @override
  State<SeriSonucuEkrani> createState() => _SeriSonucuEkraniState();
}

class _SeriSonucuEkraniState extends State<SeriSonucuEkrani> {
  ({int giris, int net})? masa;
  OnlineProfil? profil;
  int? galibiyet; // seri galibiyet yuzdesi
  List<({String oyunKodu, String? kazananUid, String durum})> maclar = [];

  OnlineMacBilgi get b => widget.kanal.bilgi;
  String get _benimUid => b.seatUid(b.benimSiram);
  bool? get _kazandim => widget.durum.kazananUid == null
      ? null
      : widget.durum.kazananUid == _benimUid;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final servis = OnlineServis();
    try {
      final m = b.dostluk ? null : await servis.masaOdul(b.masaKod, b.mod);
      final p = await servis.profilGetir();
      final maclarL = await servis.seriMaclari(b.seriId);
      int? g;
      if (p != null) {
        final ist = await servis.istatistik();
        g = ist.seri == 0 ? null : ist.galibiyet;
      }
      if (mounted) {
        setState(() {
          masa = m;
          profil = p;
          galibiyet = g;
          maclar = maclarL.where((x) => x.durum == 'bitti').toList();
        });
      }
    } catch (_) {
      // susleme verisi — gelmezse kartlar "—" gosterir
    }
  }

  List<int?> get _dotlar {
    final d = List<int?>.filled(b.mod == 'bo3' ? 3 : 1, null);
    for (var i = 0; i < maclar.length && i < d.length; i++) {
      d[i] = maclar[i].kazananUid == null
          ? null
          : (maclar[i].kazananUid == _benimUid ? 0 : 1);
    }
    return d;
  }

  (String, String) get _odul {
    if (b.dostluk) return ('±0', 'dostluk maçı');
    final m = masa;
    if (m == null) return ('—', '');
    return switch (_kazandim) {
      true => ('+${m.net}', 'Riva'),
      false => ('-${m.giris}', 'Riva'),
      null => ('±0', 'iade edildi'),
    };
  }

  void _paylas() {
    final skorum = b.benimSiram == 0 ? widget.durum.skor1 : widget.durum.skor2;
    final skorRakip =
        b.benimSiram == 0 ? widget.durum.skor2 : widget.durum.skor1;
    final metin = _kazandim == true
        ? 'GOLRIVA: ${b.rakipAdi} karşısında $skorum-$skorRakip '
            'seriyi aldım! Futbol zekâsı düellosuna sen de gel.'
        : 'GOLRIVA: ${b.rakipAdi} ile $skorum-$skorRakip kapıştık. '
            'Futbol zekâsı düellosuna sen de gel.';
    Clipboard.setData(ClipboardData(text: metin));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sonuç panoya kopyalandı')));
  }

  @override
  Widget build(BuildContext context) {
    final skorum = b.benimSiram == 0 ? widget.durum.skor1 : widget.durum.skor2;
    final skorRakip =
        b.benimSiram == 0 ? widget.durum.skor2 : widget.durum.skor1;
    final (odulDeger, odulAlt) = _odul;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('SERİ SONUCU',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: SvgPicture.asset('assets/brand/beyin_top.svg',
                    width: 64, height: 64),
              ),
              const SizedBox(height: 14),
              Center(
                child: _kazandim == true
                    ? goldYazi('KAZANDIN!', boyut: 44, bosluk: 2)
                    : Text(_kazandim == false ? 'KAYBETTİN' : 'BERABERE',
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            height: 1,
                            color: _kazandim == false
                                ? GolrivaColors.ink
                                : GolrivaColors.dim)),
              ),
              const SizedBox(height: 12),
              Center(
                child: seriNoktalari(_dotlar,
                    on: 'SERİ', arka: '$skorum-$skorRakip'),
              ),
              const SizedBox(height: 14),
              // ── ÖDÜL / ELO / GALİBİYET ──
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: gKartDekor(r: 22),
                child: Row(children: [
                  _istatKolon(
                      'ÖDÜL',
                      odulDeger,
                      odulAlt,
                      _kazandim == true
                          ? GolrivaColors.ok
                          : _kazandim == false
                              ? GolrivaColors.bad
                              : GolrivaColors.dim),
                  _istatKolon(
                      'ELO',
                      profil == null ? '—' : '${profil!.elo}',
                      profil == null
                          ? ''
                          : (ligAdlari[profil!.ligKod] ?? profil!.ligKod),
                      GolrivaColors.goldHi),
                  _istatKolon(
                      'GALİBİYET',
                      galibiyet == null ? '—' : '%$galibiyet',
                      'seri oranı',
                      GolrivaColors.goldHi),
                ]),
              ),
              // ── OYUNLAR ✓/✗ ──
              if (maclar.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: kartDekor(),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text('Oyunlar:',
                          style: GoogleFonts.figtree(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: GolrivaColors.ink)),
                      for (final m in maclar) ...[
                        Text(onlineOyunAdlari[m.oyunKodu] ?? m.oyunKodu,
                            style: GoogleFonts.figtree(
                                fontSize: 11, color: GolrivaColors.dim)),
                        m.kazananUid == null
                            ? Text('=',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11, color: GolrivaColors.dim))
                            : gIkon(
                                m.kazananUid == _benimUid ? 'onay' : 'carpi',
                                13,
                                m.kazananUid == _benimUid
                                    ? GolrivaColors.ok
                                    : GolrivaColors.bad),
                        if (m != maclar.last)
                          Text('·',
                              style: GoogleFonts.figtree(
                                  fontSize: 11, color: GolrivaColors.dim2)),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // ── RÖVANŞ + PAYLAŞ ──
              Row(children: [
                if (widget.kanal.rovansEkranKur != null) ...[
                  Expanded(
                    child: goldButon('RÖVANŞ', () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (_) => widget.kanal.rovansEkranKur!()));
                    }, yazi: 15),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _paylas,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      decoration: kartDekor(),
                      child: Text('PAYLAŞ',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: GolrivaColors.ink)),
                    ),
                  ),
                ),
              ]),
              // VERİ İTİRAZI (kullanici istegi: oyun bitiminde bildirim yolu)
              Center(
                child: TextButton(
                  onPressed: () => veriItirazDialog(context),
                  child: const Text('Futbolcu verisi yanlış mı? VERİ İTİRAZI',
                      style:
                          TextStyle(color: GolrivaColors.dim, fontSize: 11.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _istatKolon(String etiketS, String deger, String alt, Color renk) =>
      Expanded(
        child: Column(children: [
          Text(etiketS,
              style: GoogleFonts.figtree(
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.dim)),
          const SizedBox(height: 3),
          Text(deger,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: renk)),
          const SizedBox(height: 3),
          Text(alt,
              style: GoogleFonts.figtree(
                  fontSize: 9, color: GolrivaColors.dim)),
        ]),
      );
}
