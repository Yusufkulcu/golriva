import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'hata_raporu.dart';
import 'mac_kanali.dart' show siraRakibeTitresim;
import 'online_servis.dart';
import 'oturum_bekcisi.dart';
import 'oyun_yonlendirici.dart';

/// RAKİP ARAMA — lobiden HIZLI DÜELLO / BO3 SERİ ile gelinir; masa ve mod
/// secimi lobide yapilmistir. Kuyruga otomatik girilir, rakip bulunur
/// bulunmaz rulet/VS ekranina gecilir (tercih kullaniciya birakilmaz).
class AramaEkrani extends StatefulWidget {
  final GolrivaRepos repos;
  final String mod; // bo1 / bo3
  final String masaKod;
  const AramaEkrani(
      {super.key, required this.repos, required this.mod, required this.masaKod});

  @override
  State<AramaEkrani> createState() => _AramaEkraniState();
}

class _AramaEkraniState extends State<AramaEkrani> {
  final servis = OnlineServis();
  Timer? nabiz;
  int beklemeSn = 0;
  String? hata;
  bool kuyrukta = false;
  DateTime? kuyrukAni;

  @override
  void initState() {
    super.initState();
    _basla();
  }

  Future<void> _basla() async {
    try {
      // ANTİ-HİLE: kuyruğa girmeden önce bu cihazın aktif oturum olduğunu
      // doğrula. Değilse (başka cihazdan giriş yapılmış) çıkış yaptırır.
      if (!await OturumBekcisi().dogrula()) return;
      await servis.kuyrugaGir(widget.mod, widget.masaKod);
      // HAYALET ESLESME KALKANI: yalnizca kuyruga giristen SONRA kurulan
      // seriler kabul edilir (5 sn saat payi).
      final simdi = await servis.sunucuSaati();
      kuyrukAni = (simdi ?? DateTime.now().toUtc())
          .subtract(const Duration(seconds: 5));
      kuyrukta = true;
      nabiz = Timer.periodic(const Duration(seconds: 3), (_) => _kontrol());
      if (mounted) setState(() {});
    } catch (e, s) {
      if (mounted) {
        setState(() => hata = '$e'.contains('yetersiz')
            ? 'Yetersiz bakiye — bu masa için RIVA gerekiyor.'
            : temizMesaj('arama._basla', e,
                'Kuyruğa şu an girilemedi — tekrar dene.', s));
      }
    }
  }

  Future<void> _kontrol() async {
    beklemeSn += 3;
    try {
      final s = await servis.eslesmeKontrol(seriAltSiniri: kuyrukAni);
      if (!mounted) return;
      if (s != null) {
        nabiz?.cancel();
        kuyrukta = false;
        siraRakibeTitresim(); // RAKIP BULUNDU — hafif dokunus
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => onlineOyunEkrani(widget.repos, s)));
      } else {
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    nabiz?.cancel();
    // ekrandan ayrilmak = kuyruktan cikmak (sunucu nabzi ayrica garanti eder)
    if (kuyrukta) servis.kuyruktanCik().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('RAKİP ARANIYOR',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: hata != null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(hata!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 13, color: GolrivaColors.bad)),
                    const SizedBox(height: 14),
                    OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('GERİ')),
                  ])
                : Container(
                    padding: const EdgeInsets.all(24),
                    decoration: gKartDekor(r: 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(
                          color: GolrivaColors.gold),
                      const SizedBox(height: 16),
                      Text('RAKİP ARANIYOR…',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(
                          '$beklemeSn sn · ${widget.masaKod.toUpperCase()} · '
                          '${widget.mod == "bo3" ? "3 MAÇLIK SERİ" : "TEK MAÇ"}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, color: GolrivaColors.dim)),
                      const SizedBox(height: 8),
                      Text('Rakip bulunduğu an 3-2-1 ile maça alınırsın.',
                          style: GoogleFonts.figtree(
                              fontSize: 11, color: GolrivaColors.dim2)),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: GolrivaColors.ink,
                            side:
                                const BorderSide(color: GolrivaColors.edge2)),
                        onPressed: () => Navigator.pop(context),
                        child: Text('VAZGEÇ',
                            style: GoogleFonts.bigShouldersDisplay(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2)),
                      ),
                    ]),
                  ),
          ),
        ),
      ),
    );
  }
}
