import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../theme/golriva_theme.dart';
import 'mac_kanali.dart';
import 'online_servis.dart';
import 'oyun_yonlendirici.dart';

/// RANKED kuyruk: masa + mod sec, kuyruga gir, eslesmeyi bekle.
/// Oyun SECILMEZ — rulet sunucuda doner, eslesince ogrenilir (kullanici kurali).
class KuyrukEkrani extends StatefulWidget {
  final OnlineProfil profil;
  final GolrivaRepos repos;
  const KuyrukEkrani({super.key, required this.profil, required this.repos});

  @override
  State<KuyrukEkrani> createState() => _KuyrukEkraniState();
}

class _KuyrukEkraniState extends State<KuyrukEkrani> {
  final servis = OnlineServis();
  List<Masa>? masalar;
  String mod = 'bo1';
  String? seciliMasa;
  bool kuyrukta = false;
  int beklemeSn = 0;
  Timer? nabiz;
  String? hata;
  OnlineMacBilgi? eslesme;

  @override
  void initState() {
    super.initState();
    servis.masalar().then(
        (m) => mounted
            ? setState(() {
                masalar = m;
                seciliMasa = m.isNotEmpty ? m.first.kod : null;
              })
            : null, onError: (e) {
      if (mounted) setState(() => hata = 'Masalar yüklenemedi: $e');
    });
  }

  int _giris(Masa m) => mod == 'bo3' ? m.girisBo3 : m.giris;

  Future<void> _kuyrugaGir() async {
    if (seciliMasa == null) return;
    setState(() {
      hata = null;
      kuyrukta = true;
      beklemeSn = 0;
    });
    try {
      await servis.kuyrugaGir(mod, seciliMasa!);
      nabiz = Timer.periodic(const Duration(seconds: 3), (_) => _kontrol());
    } catch (e) {
      setState(() {
        kuyrukta = false;
        hata = '$e'.contains('yetersiz')
            ? 'Yetersiz bakiye — bu masa için RIVA gerekiyor'
            : 'Kuyruğa girilemedi: $e';
      });
    }
  }

  Future<void> _kontrol() async {
    beklemeSn += 3;
    try {
      final s = await servis.eslesmeKontrol();
      if (!mounted) return;
      if (s != null) {
        nabiz?.cancel();
        setState(() {
          eslesme = s;
          kuyrukta = false;
        });
      } else {
        setState(() {});
      }
    } catch (_) {
      // gecici ag hatasi: nabiz devam eder
    }
  }

  Future<void> _iptal() async {
    nabiz?.cancel();
    try {
      await servis.kuyruktanCik();
    } catch (_) {}
    if (mounted) setState(() => kuyrukta = false);
  }

  @override
  void dispose() {
    nabiz?.cancel();
    // EKRANDAN AYRILMAK = KUYRUKTAN CIKMAK (kullanici kurali: eslesme
    // yalnizca iki taraf da aktif bekliyorsa kurulur). Sunucudaki nabiz
    // (son_gorulme) bunu ayrica garanti eder — uygulama olse bile kayit
    // 12 sn icinde eslesme disinda kalir.
    if (kuyrukta && eslesme == null) {
      servis.kuyruktanCik().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text('RANKED MAÇ',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          Text('${widget.profil.kullaniciAdi} · ${widget.profil.bakiye} RIVA',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  color: GolrivaColors.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ]),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            if (eslesme != null)
              _eslesmeKarti()
            else if (kuyrukta)
              _beklemeKarti()
            else ...[
              Text('MOD',
                  style: GoogleFonts.figtree(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: GolrivaColors.dim,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                _modSecim('bo1', 'TEK MAÇ'),
                const SizedBox(width: 8),
                _modSecim('bo3', '3 MAÇLIK SERİ'),
              ]),
              const SizedBox(height: 14),
              Text('MASA',
                  style: GoogleFonts.figtree(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: GolrivaColors.dim,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (masalar == null)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            color: GolrivaColors.gold)))
              else
                for (final m in masalar!) _masaKarti(m),
              if (hata != null) ...[
                const SizedBox(height: 8),
                Text(hata!,
                    style: GoogleFonts.figtree(
                        fontSize: 12,
                        color: GolrivaColors.bad,
                        fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: GolrivaColors.gold,
                    foregroundColor: const Color(0xFF231A04),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: seciliMasa == null ? null : _kuyrugaGir,
                child: Text('KUYRUĞA GİR',
                    style: GoogleFonts.bigShouldersDisplay(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        fontSize: 17)),
              ),
              const SizedBox(height: 8),
              Text(
                  'Oyun seçilmez: rulet sunucuda döner, rakip bulununca '
                  'hangi oyunun geldiğini ikiniz de aynı anda öğrenirsiniz.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(
                      fontSize: 11, color: GolrivaColors.dim)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modSecim(String k, String ad) {
    final secili = mod == k;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => mod = k),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: secili
                ? GolrivaColors.gold.withValues(alpha: .14)
                : GolrivaColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: secili ? GolrivaColors.gold : GolrivaColors.edge2),
          ),
          child: Text(ad,
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: secili ? GolrivaColors.goldHi : GolrivaColors.dim)),
        ),
      ),
    );
  }

  Widget _masaKarti(Masa m) {
    final secili = seciliMasa == m.kod;
    final kilitli = widget.profil.bakiye < m.minBakiyeKilit ||
        widget.profil.bakiye < _giris(m);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: kilitli ? null : () => setState(() => seciliMasa = m.kod),
      child: Opacity(
        opacity: kilitli ? .45 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: secili
                ? GolrivaColors.gold.withValues(alpha: .12)
                : GolrivaColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: secili ? GolrivaColors.gold : GolrivaColors.edge2),
          ),
          child: Row(children: [
            Expanded(
              child: Text(m.kod.toUpperCase(),
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
            ),
            Text(kilitli ? 'KİLİTLİ' : 'giriş ${_giris(m)} RIVA',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        kilitli ? GolrivaColors.bad : GolrivaColors.goldHi)),
          ]),
        ),
      ),
    );
  }

  Widget _beklemeKarti() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22D4AF37), GolrivaColors.card]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GolrivaColors.edge),
        ),
        child: Column(children: [
          const CircularProgressIndicator(color: GolrivaColors.gold),
          const SizedBox(height: 14),
          Text('RAKİP ARANIYOR…',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Text('$beklemeSn sn · ${seciliMasa?.toUpperCase()} · ${mod.toUpperCase()}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, color: GolrivaColors.dim)),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: GolrivaColors.ink,
                side: const BorderSide(color: GolrivaColors.edge2)),
            onPressed: _iptal,
            child: Text('VAZGEÇ',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w800, letterSpacing: 2)),
          ),
        ]),
      );

  Widget _eslesmeKarti() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22D4AF37), GolrivaColors.card]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GolrivaColors.edge),
        ),
        child: Column(children: [
          Text('RAKİP BULUNDU',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: GolrivaColors.goldHi,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(eslesme!.rakipAdi,
              style: GoogleFonts.figtree(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.p2)),
          const SizedBox(height: 14),
          Text('RULETİN SEÇTİĞİ OYUN',
              style: GoogleFonts.figtree(
                  fontSize: 9,
                  letterSpacing: 2.5,
                  color: GolrivaColors.dim,
                  fontWeight: FontWeight.w700)),
          Text(onlineOyunAdlari[eslesme!.oyunKodu] ?? eslesme!.oyunKodu,
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: GolrivaColors.gold,
                foregroundColor: const Color(0xFF231A04),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 13)),
            onPressed: () {
              final b = eslesme!;
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => onlineOyunEkrani(widget.repos, b)));
            },
            child: Text('MAÇA BAŞLA',
                style: GoogleFonts.bigShouldersDisplay(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 18)),
          ),
          const SizedBox(height: 8),
          Text('${eslesme!.mod == "bo3" ? "3 maçlık seri" : "Tek maç"} · '
              'sıra tabanlı senkron · yanlış anda hamle yapılamaz',
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.figtree(fontSize: 10.5, color: GolrivaColors.dim)),
        ]),
      );
}
