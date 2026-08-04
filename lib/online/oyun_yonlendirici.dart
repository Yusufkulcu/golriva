import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../reklam/reklam_servis.dart';
import '../games/en_genc_kadro/screen.dart';
import '../games/en_kisa_kadro/screen.dart';
import '../games/hedefi_tuttur/screen.dart';
import '../games/kor_av/screen.dart';
import '../games/kupa_drafti/screen.dart';
import '../games/serbest_kadro/engine.dart';
import '../games/serbest_kadro/screen.dart';
import '../screens/oyna_sekmesi.dart' show ligAdlari;
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'hata_raporu.dart';
import 'arama_ekrani.dart';
import 'mac_kanali.dart';
import 'online_servis.dart';
import 'seri_sonucu_ekrani.dart';

const onlineOyunAdlari = {
  'en_kisa_kadro': 'EN KISA KADRO',
  'kupa_drafti': 'KUPA DRAFTI',
  'en_genc_kadro': 'EN GENÇ KADRO',
  'bayrak_yarisi': 'BAYRAK YARIŞI',
  'hedefi_tuttur': 'HEDEFİ TUTTUR',
  'bonservis_avi': 'BONSERVİS AVI',
  'sari_kart_avi': 'SARI KART AVI',
  'mac_rekortmenleri': 'MAÇ REKORTMENLERİ',
  'milli_gol_krallari': 'MİLLİ GOL KRALLARI',
  'kariyer_ikizi': 'KARİYER İKİZİ',
};

/// _oyunEkrani'nin su an destekledigi cevrimici oyunlar — davet kurarken
/// oyun secimi bu listeden yapilir (bayrak + ikiz online Faz 2.5).
const onlineOynanabilir = [
  'en_kisa_kadro',
  'kupa_drafti',
  'en_genc_kadro',
  'hedefi_tuttur',
  'bonservis_avi',
  'sari_kart_avi',
  'mac_rekortmenleri',
  'milli_gol_krallari',
];

/// oyun_kodu → cevrimici oyun akisi. Once SENKRON BAGLANTI ekrani gelir:
/// iki cihaz otomatik el sikisir, 3-2-1 sunucu saatiyle ayni anda maca girilir
/// (kullanici kurali: tercih kullaniciya birakilmaz, sayaclar es zamanli).
Widget onlineOyunEkrani(GolrivaRepos repos, OnlineMacBilgi bilgi) {
  final kanal = OnlineMacKanali(bilgi);
  kanal.sonrakiEkranKur = (b) => onlineOyunEkrani(repos, b);
  if (bilgi.masaKod.isNotEmpty && !bilgi.dostluk) {
    // Seri sonucu ekranindaki RÖVANŞ: ayni masa + ayni modla yeni arama
    // (dostlukta rovans yeni davet gerektirir — buton gosterilmez)
    kanal.rovansEkranKur = () =>
        AramaEkrani(repos: repos, mod: bilgi.mod, masaKod: bilgi.masaKod);
  }
  return OnlineHazirlikEkrani(
      kanal: kanal, oyunEkraniKur: () => _oyunEkrani(repos, kanal));
}

Widget _oyunEkrani(GolrivaRepos repos, OnlineMacKanali kanal) {
  final bilgi = kanal.bilgi;
  switch (bilgi.oyunKodu) {
    case 'en_kisa_kadro':
      return EnKisaKadroScreen(repo: repos.boy, online: kanal);
    case 'en_genc_kadro':
      return EnGencKadroScreen(repo: repos.genc, online: kanal);
    case 'kupa_drafti':
      return KupaDraftiScreen(repo: repos.kupa, online: kanal);
    case 'hedefi_tuttur':
      return HedefiTutturScreen(repo: repos.hedef, online: kanal);
    case 'bonservis_avi':
      return KorAvScreen(
          repo: repos.fee, config: bonservisConfig, online: kanal);
    case 'sari_kart_avi':
      return KorAvScreen(
          repo: repos.card, config: sariKartConfig, online: kanal);
    case 'mac_rekortmenleri':
      return SerbestKadroScreen(
          repo: repos.mac, config: macConfig, online: kanal);
    case 'milli_gol_krallari':
      return SerbestKadroScreen(
          repo: repos.milligol, config: milligolConfig, online: kanal);
    default:
      return Scaffold(
          body: Center(
              child: Text('Bilinmeyen oyun: ${bilgi.oyunKodu}',
                  style: GoogleFonts.figtree(color: GolrivaColors.bad))));
  }
}

/// Cekilme akisi: onay → rakibi kazanan bildir → seri akisi dialogu.
/// [onCekildi] onay VERILDIKTEN sonra cagrilir (ekran sayacini durdurmak
/// icin) — vazgecilirse mac kesintisiz devam eder.
Future<void> cekilAkisi(BuildContext context, OnlineMacKanali kanal,
    {VoidCallback? onCekildi}) async {
  final onay = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: GolrivaColors.card,
      title: Text('Maçtan çekil?',
          style: GoogleFonts.bigShouldersDisplay(
              fontWeight: FontWeight.w900, color: GolrivaColors.ink)),
      content: Text('Bu maç hükmen rakibin olur.',
          style: GoogleFonts.figtree(color: GolrivaColors.dim)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('VAZGEÇ')),
        TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ÇEKİL',
                style: TextStyle(color: GolrivaColors.bad))),
      ],
    ),
  );
  if (onay != true || !context.mounted) return;
  onCekildi?.call();
  // Rakibin ekrani ANINDA ogrensin diye kanala cekilme sinyali birak
  // (kanal ayrica mac durumunu da yoklar — cifte emniyet).
  kanal.gonder({'tip': 'cekildi'});
  final rakipSeat = kanal.bilgi.benimSiram == 0 ? 1 : 0;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: GolrivaColors.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: GolrivaColors.edge)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('MAÇTAN ÇEKİLDİN',
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: GolrivaColors.bad,
                  letterSpacing: 1.5)),
          const SizedBox(height: 12),
          OnlineSonucButonlari(kanal: kanal, kazananSeat: rakipSeat),
        ]),
      ),
    ),
  );
}

/// SENKRON BAGLANTI EKRANI: rakip bulununca iki cihaz OTOMATIK el sikisir
/// (kullaniciya buton yok), iki sinyal de sunucuya dusunce 3-2-1 geri sayim
/// SUNUCU saatiyle es zamanli baslar ve mac ayni anda acilir.
class OnlineHazirlikEkrani extends StatefulWidget {
  final OnlineMacKanali kanal;
  final Widget Function() oyunEkraniKur;
  const OnlineHazirlikEkrani(
      {super.key, required this.kanal, required this.oyunEkraniKur});

  @override
  State<OnlineHazirlikEkrani> createState() => _OnlineHazirlikEkraniState();
}

class _OnlineHazirlikEkraniState extends State<OnlineHazirlikEkrani> {
  bool benHazir = false;
  bool rakipHazir = false;
  bool rakipCekildi = false;
  bool cekildim = false; // VAZGEÇ onaylandi — ARTIK MACA GIRILMEZ
  bool hedefAraniyor = false;
  DateTime? baslangicHedefi; // yerel saate cevrilmis SUNUCU hedefi
  int? geriSayim;
  Timer? sayimTimer;

  // Tasarim seti ekran 2 icin ek bilgiler (hepsi firsatci — gelmezse
  // ekran yine calisir, sadece o satirlar bos kalir):
  ({String ad, int elo, String ligKod})? benProfil, rakipProfil;
  List<int?> seriDotlar = [];
  int oyunNo = 1;
  ({int giris, int net})? masa;

  @override
  void initState() {
    super.initState();
    widget.kanal.basla(_hamle, onMacKapandi: _kapandi);
    // OTOMATIK EL SIKISMA: ekran acilir acilmaz "buradayim" sinyali —
    // kullanicidan HAZIR istenmez (kullanici kurali). Iki sinyal de
    // sunucuya dusunce geri sayim sunucu saatiyle es zamanli baslar.
    benHazir = true;
    widget.kanal.gonder({'tip': 'hazir'});
    _bilgileriYukle();
  }

  Future<void> _bilgileriYukle() async {
    final b = widget.kanal.bilgi;
    final servis = OnlineServis();
    try {
      final ben = await servis.kamuProfil(b.seatUid(b.benimSiram));
      final rakip = await servis.kamuProfil(b.seatUid(1 - b.benimSiram));
      final maclar = await servis.seriMaclari(b.seriId);
      // dostlukta giris alinmaz — masa satiri gosterilmez
      final m = b.dostluk ? null : await servis.masaOdul(b.masaKod, b.mod);
      if (!mounted) return;
      final biten = maclar.where((x) => x.durum == 'bitti').toList();
      final benimUid = b.seatUid(b.benimSiram);
      final dotlar = List<int?>.filled(b.mod == 'bo3' ? 3 : 1, null);
      for (var i = 0; i < biten.length && i < dotlar.length; i++) {
        dotlar[i] = biten[i].kazananUid == null
            ? null
            : (biten[i].kazananUid == benimUid ? 0 : 1);
      }
      setState(() {
        benProfil = ben;
        rakipProfil = rakip;
        seriDotlar = dotlar;
        oyunNo = biten.length + 1;
        masa = m;
      });
    } catch (_) {
      // susleme verisi — hata halinde sade gorunumle devam
    }
  }

  void _hamle(Map<String, dynamic> h) {
    if (!mounted) return;
    if (h['tip'] == 'hazir') {
      // rakibin baglandigi ANINDA gosterilir (kullanici istegi)
      setState(() => rakipHazir = true);
      _kontrol();
    } else if (h['tip'] == 'cekildi') {
      _kapandi();
    }
  }

  void _kapandi() {
    if (!mounted || rakipCekildi || baslangicHedefi != null) return;
    setState(() => rakipCekildi = true);
  }

  /// Iki taraf da hazirsa SUNUCU-SENKRON hedefi bul: baslangic ani
  /// = ikinci hazir'in sunucu zamani + 4 sn. Iki cihaz da ayni mutlak
  /// ani hedefler → geri sayim es zamanli biter (kullanici kurali).
  void _kontrol() {
    if (!benHazir || !rakipHazir || hedefAraniyor || cekildim) return;
    hedefAraniyor = true;
    _hedefiBul();
  }

  Future<void> _hedefiBul() async {
    for (var deneme = 0; deneme < 12 && mounted; deneme++) {
      try {
        final kalan = await widget.kanal.hazirGeriSayimKalan();
        if (kalan != null) {
          _sayimiBaslat(kalan.inMilliseconds < 300
              ? const Duration(milliseconds: 300)
              : kalan);
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 400));
    }
    // sunucu saati alinamadiysa yerel 3 sn ile yine de basla
    if (mounted) _sayimiBaslat(const Duration(seconds: 3));
  }

  void _sayimiBaslat(Duration kalan) {
    if (!mounted || cekildim || baslangicHedefi != null) return;
    setState(() => baslangicHedefi = DateTime.now().add(kalan));
    _sayimTikla();
    sayimTimer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => _sayimTikla());
  }

  void _sayimTikla() {
    // KULLANICI HATASI DUZELTMESI: VAZGEÇ onaylandiysa geri sayim
    // calismaya devam edip maca SOKMAMALI.
    if (!mounted || cekildim || baslangicHedefi == null) return;
    final kalanMs =
        baslangicHedefi!.difference(DateTime.now()).inMilliseconds;
    if (kalanMs <= 0) {
      sayimTimer?.cancel();
      siraBanaTitresim(); // MAC BASLIYOR — elde de hissedilsin
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.oyunEkraniKur()));
    } else {
      final s = (kalanMs / 1000).ceil();
      if (s != geriSayim) setState(() => geriSayim = s);
    }
  }

  @override
  void dispose() {
    sayimTimer?.cancel();
    // DIKKAT: kanal.kapat() YOK — kanal oyun ekranina devrediliyor.
    super.dispose();
  }

  /// Rulet seridinde ortadaki (secilen) oyunun sag/sol komsulari —
  /// tasarim ekran 2'deki "soluk isim · ALTIN ISIM · soluk isim" dizisi.
  (String, String) _komsuOyunlar(String kod) {
    final adlar = onlineOyunAdlari.values.toList();
    final kodlar = onlineOyunAdlari.keys.toList();
    final i = kodlar.indexOf(kod);
    if (i < 0) return ('', '');
    return (
      adlar[(i - 1 + adlar.length) % adlar.length],
      adlar[(i + 1) % adlar.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.kanal.bilgi;
    final (solOyun, sagOyun) = _komsuOyunlar(b.oyunKodu);
    return PopScope(
      canPop: false, // geri tusu ile sessiz kacis yok — VAZGEÇ hukmen sayilir
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text('MAÇ BULUNDU',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                // ── VS SATIRI (tasarim ekran 2) ──
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _oyuncuKolonu(
                              ad: benProfil?.ad ?? 'SEN',
                              profil: benProfil,
                              renk: GolrivaColors.p1,
                              hazir: benHazir)),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: goldYazi('VS', boyut: 34),
                      ),
                      Expanded(
                          child: _oyuncuKolonu(
                              ad: b.rakipAdi,
                              profil: rakipProfil,
                              renk: GolrivaColors.p2,
                              hazir: rakipHazir)),
                    ]),
                const SizedBox(height: 16),
                // ── SERI NOKTALARI ──
                Center(
                  child: seriNoktalari(seriDotlar,
                      on: b.mod.toUpperCase(), arka: '$oyunNo. OYUN'),
                ),
                const SizedBox(height: 16),
                // ── RULET KARTI ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
                  decoration: gKartDekor(r: 24),
                  child: Column(children: [
                    Text('OYUN SEÇİLİYOR',
                        style: GoogleFonts.figtree(
                            fontSize: 9.5,
                            letterSpacing: 3,
                            color: GolrivaColors.dim,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Opacity(
                              opacity: .5,
                              child: Text(solOyun,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.bigShouldersDisplay(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      color: GolrivaColors.dim2)),
                            ),
                          ),
                          Flexible(
                            flex: 3,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: goldYazi(
                                    onlineOyunAdlari[b.oyunKodu] ?? b.oyunKodu,
                                    boyut: 26,
                                    bosluk: 1),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Opacity(
                              opacity: .5,
                              child: Text(sagOyun,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.bigShouldersDisplay(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      color: GolrivaColors.dim2)),
                            ),
                          ),
                        ]),
                    const SizedBox(height: 16),
                    // altin isik cizgisi
                    Container(
                      height: 3,
                      width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(colors: [
                          Colors.transparent,
                          GolrivaColors.gold,
                          Colors.transparent
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rakipCekildi) ...[
                      Text('RAKİP ÇEKİLDİ',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: GolrivaColors.goldHi,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 10),
                      OnlineSonucButonlari(
                          kanal: widget.kanal, kazananSeat: b.benimSiram),
                    ] else if (baslangicHedefi != null) ...[
                      Text('${geriSayim ?? ""}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              height: 1,
                              color: GolrivaColors.goldHi)),
                      const SizedBox(height: 4),
                      Text('MAÇ BAŞLIYOR',
                          style: GoogleFonts.figtree(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: GolrivaColors.dim,
                              fontWeight: FontWeight.w700)),
                    ] else ...[
                      // OTOMATIK EL SIKISMA (kullanici kurali): buton yok —
                      // iki cihaz baglandigi an geri sayim kendiliginden baslar.
                      Text('Rulet dönüyor… kimse önden plan yapamaz',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.figtree(
                              fontSize: 10.5, color: GolrivaColors.dim)),
                      const SizedBox(height: 4),
                      Text('${b.rakipAdi} bağlanıyor…',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.figtree(
                              fontSize: 11.5, color: GolrivaColors.dim2)),
                    ],
                  ]),
                ),
                // ── MASA / GIRIS BILGISI ──
                if (b.dostluk) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text('DOSTLUK MAÇI · Riva ve Elo işlemez',
                        style: GoogleFonts.figtree(
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                            color: GolrivaColors.dim)),
                  ),
                ] else if (masa != null) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text.rich(
                      TextSpan(
                          style: GoogleFonts.figtree(
                              fontSize: 11, color: GolrivaColors.dim),
                          children: [
                            const TextSpan(text: 'Masa: '),
                            TextSpan(
                                text: b.masaKod.toUpperCase(),
                                style: GoogleFonts.figtree(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: GolrivaColors.goldHi)),
                            const TextSpan(text: ' · Seri girişi '),
                            TextSpan(
                                text: '${masa!.giris}',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: GolrivaColors.goldHi)),
                            const TextSpan(text: ' Riva alındı'),
                          ]),
                    ),
                  ),
                ],
                if (!rakipCekildi && baslangicHedefi == null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: GolrivaColors.dim,
                          side: const BorderSide(color: GolrivaColors.edge2)),
                      onPressed: () => cekilAkisi(context, widget.kanal,
                          onCekildi: () {
                        // onay ANINDA sayaci durdur — geri sayim bitse bile
                        // maca girilmez (kullanici hatasi duzeltmesi)
                        cekildim = true;
                        sayimTimer?.cancel();
                      }),
                      child: Text('VAZGEÇ (HÜKMEN)',
                          style: GoogleFonts.bigShouldersDisplay(
                              fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// VS satirindaki oyuncu kolonu: avatar (takim renginde cerceve) + ad +
  /// "elo · LİG" + baglanti durumu (kullanici istegi: hazir gostergesi).
  Widget _oyuncuKolonu(
      {required String ad,
      required ({String ad, int elo, String ligKod})? profil,
      required Color renk,
      required bool hazir}) {
    return Column(children: [
      Container(
        decoration: hazir
            ? BoxDecoration(shape: BoxShape.circle, boxShadow: [
                BoxShadow(color: renk.withValues(alpha: .35), blurRadius: 16)
              ])
            : null,
        child: avatar(ad, 58, kenar: renk, kalinlik: 2),
      ),
      const SizedBox(height: 6),
      Text(ad.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.bigShouldersDisplay(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: renk)),
      if (profil != null)
        Text.rich(
          TextSpan(
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, color: GolrivaColors.dim),
              children: [
                TextSpan(text: '${profil.elo} · '),
                TextSpan(
                    text: ligAdlari[profil.ligKod] ?? profil.ligKod,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, color: GolrivaColors.gold)),
              ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      const SizedBox(height: 3),
      Text(hazir ? 'BAĞLANDI' : 'bekleniyor…',
          style: GoogleFonts.figtree(
              fontSize: 9,
              fontWeight: hazir ? FontWeight.w800 : FontWeight.w500,
              fontStyle: hazir ? FontStyle.normal : FontStyle.italic,
              letterSpacing: hazir ? 1.5 : 0,
              color: hazir ? GolrivaColors.ok : GolrivaColors.dim2)),
    ]);
  }
}

/// Mac sonu ONLINE butonlari: sonucu sunucuya bildirir, seri durumuna gore
/// "SONRAKİ MAÇ" (bo3 devam) ya da seri sonucu + "LOBİYE DÖN" gosterir.
/// Iki istemci de bildirir; sunucu ilk raporu isler (cift islem imkansiz).
class OnlineSonucButonlari extends StatefulWidget {
  final OnlineMacKanali kanal;
  final int? kazananSeat; // 0/1/null(berabere)
  const OnlineSonucButonlari(
      {super.key, required this.kanal, required this.kazananSeat});

  @override
  State<OnlineSonucButonlari> createState() => _OnlineSonucButonlariState();
}

class _OnlineSonucButonlariState extends State<OnlineSonucButonlari> {
  OnlineSeriDurumu? durum;
  String? hata;

  @override
  void initState() {
    super.initState();
    widget.kanal.kapat(); // hamle yoklamasi biter
    // Maç sonu geçiş reklamını önden yükle (seri bitince hazır olsun).
    ReklamServis.gecisHazirla();
    widget.kanal.sonucBildir(widget.kazananSeat).then(
        (d) => mounted ? setState(() => durum = d) : null,
        onError: (e, StackTrace s) {
      if (mounted) {
        setState(() => hata = temizMesaj('sonuc._bildir', e as Object,
            'Sonuç işlenirken sorun oluştu — Riva ödülün güvende, '
            'lobiden kontrol edebilirsin.', s));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hata != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$hata',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
                fontSize: 12, color: GolrivaColors.bad)),
        const SizedBox(height: 8),
        _lobiButonu(context),
      ]);
    }
    final d = durum;
    if (d == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: GolrivaColors.gold, strokeWidth: 2.5)),
        const SizedBox(height: 6),
        Text('Sonuç sunucuya işleniyor…',
            style: GoogleFonts.figtree(
                fontSize: 11, color: GolrivaColors.dim)),
      ]);
    }
    final b = widget.kanal.bilgi;
    final skorum = b.benimSiram == 0 ? d.skor1 : d.skor2;
    final skorRakip = b.benimSiram == 0 ? d.skor2 : d.skor1;
    if (!d.seriBitti && d.sonrakiMac != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('SERİ $skorum - $skorRakip · devam ediyor',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.goldHi)),
        const SizedBox(height: 10),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: GolrivaColors.gold,
              foregroundColor: const Color(0xFF231A04),
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
          onPressed: () {
            final nav = Navigator.of(context);
            final ekran = widget.kanal.sonrakiEkranKur!(d.sonrakiMac!);
            nav.pop(); // dialogu kapat
            nav.pushReplacement(MaterialPageRoute(builder: (_) => ekran));
          },
          child: Text('SONRAKİ MAÇ',
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
        ),
      ]);
    }
    final benimUid = b.seatUid(b.benimSiram);
    final mesaj = d.kazananUid == null
        ? 'SERİ BERABERE ($skorum - $skorRakip) — girişler iade edildi'
        : d.kazananUid == benimUid
            ? 'SERİYİ KAZANDIN ($skorum - $skorRakip)'
            : 'Seriyi ${b.rakipAdi} aldı ($skorum - $skorRakip)';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(mesaj,
          textAlign: TextAlign.center,
          style: GoogleFonts.figtree(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: d.kazananUid == benimUid
                  ? GolrivaColors.ok
                  : GolrivaColors.dim)),
      const SizedBox(height: 10),
      FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: GolrivaColors.gold,
            foregroundColor: const Color(0xFF231A04),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
        onPressed: () async {
          // Tasarim ekran 8: seri sonucu KENDI tam ekraninda gosterilir.
          // Yigin lobiye kadar temizlenir; sonuc ekranindan geri = lobi.
          final nav = Navigator.of(context);
          // KARŞILAŞMA BİTİŞİ: admin limitine göre maç-sonu reklamı göster.
          await _macSonuReklami();
          nav.popUntil((r) => r.isFirst);
          nav.push(MaterialPageRoute(
              builder: (_) =>
                  SeriSonucuEkrani(kanal: widget.kanal, durum: d)));
        },
        child: Text('SERİ SONUCU',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
      ),
    ]);
  }

  Widget _lobiButonu(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: GolrivaColors.gold,
            foregroundColor: const Color(0xFF231A04),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
        onPressed: () =>
            Navigator.of(context).popUntil((r) => r.isFirst),
        child: Text('LOBİYE DÖN',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
      );

  /// KARŞILAŞMA BİTİŞİ REKLAMI — admin panelden belirlenen günlük limite
  /// göre (reklam_gosterim_hakki) maç sonunda geçiş reklamı gösterir.
  /// Hak yoksa/limit dolduysa ya da reklam hazır değilse sessizce atlar.
  Future<void> _macSonuReklami() async {
    try {
      if (!ReklamServis.destekleniyor) return;
      final hak = await OnlineServis().reklamHakki();
      if (hak <= 0) return;
      final gosterildi = await ReklamServis.gecisGoster();
      if (gosterildi) await OnlineServis().reklamGosterildi();
    } catch (e, s) {
      hataBildir('reklam.macSonu', e, s);
    }
  }
}
