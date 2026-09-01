import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../reklam/reklam_servis.dart';
import '../screens/oyna_sekmesi.dart' show ligAdlari;
import 'alig_servis.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import '../widgets/kisi_moderasyon.dart';
import 'hata_raporu.dart';
import 'itiraz_dialog.dart';
import 'mac_kanali.dart';
import 'online_servis.dart';
import 'oyun_yonlendirici.dart' show onlineOyunAdlari;
import 'uzak_ayar.dart';

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
  // FAZ 2.20 — istege bagli odullu reklam (2x / kayip iadesi)
  bool reklamOynuyor = false;
  int? ekOdul; // alinan ek Riva (null = henuz alinmadi)
  // FAZ 2.21 — admin paneldeki ORTAK gunluk limit (magaza + mac sonu):
  // hak 0 ise teklif karti hic gosterilmez.
  int reklamHak = 0;
  // FAZ 2.22 — bu seri bir ARKADAŞ LİGİ maçıysa lig kimliği
  // (LİG SAYFASI butonu için).
  String? ligId;
  // FAZ 2.25 — otomatik GEÇİŞ reklamı: ödüllü izlenmediyse çıkışta %50
  // ihtimalle (her maç türü; admin limitinden bağımsız). Karar ekran
  // açılırken verilir ve reklam ön yüklenir; çıkışta tek kez gösterilir.
  // FAZ 2.30: ihtimal ve reklam anahtarı uzak ayardan (panelden anında)
  final bool _gecisPlanli = UzakAyar.reklamAcik &&
      Random().nextInt(100) < UzakAyar.gecisReklamYuzde;
  bool _gecisDenendi = false;

  OnlineMacBilgi get b => widget.kanal.bilgi;
  String get _benimUid => b.seatUid(b.benimSiram);
  bool? get _kazandim => widget.durum.kazananUid == null
      ? null
      : widget.durum.kazananUid == _benimUid;

  @override
  void initState() {
    super.initState();
    _yukle();
    if (_gecisPlanli && ReklamServis.destekleniyor) {
      ReklamServis.gecisOnYukle(); // sessiz; yüklenemezse gösterilmez
    }
  }

  @override
  void dispose() {
    ReklamServis.gecisBirak();
    super.dispose();
  }

  /// Ekrandan ayrılırken: ödüllü izlenmediyse ve yazı-tura "evet" dediyse
  /// geçiş reklamı göster, sonra [devam] ile gerçek çıkışı yap.
  Future<void> _cikis(VoidCallback devam) async {
    if (!_gecisDenendi && _gecisPlanli && ekOdul == null && !reklamOynuyor) {
      _gecisDenendi = true;
      try {
        await ReklamServis.gecisGoster();
      } catch (e, s) {
        hataBildir('seriSonucu._cikisGecis', e, s);
      }
    }
    if (mounted) devam();
  }

  Future<void> _yukle() async {
    final servis = OnlineServis();
    try {
      final m = b.dostluk ? null : await servis.masaOdul(b.masaKod, b.mod);
      final p = await servis.profilGetir();
      final maclarL = await servis.seriMaclari(b.seriId);
      final hak = b.dostluk ? 0 : await servis.reklamHakki();
      // lig maçı mı? (lig maçları dostluk serisi olarak oynanır)
      final lid = b.dostluk ? await AligServis().seridenLigId(b.seriId) : null;
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
          reklamHak = hak;
          ligId = lid;
        });
      }
    } catch (e, s) {
      // susleme verisi — gelmezse kartlar "—" gosterir; yine de rapor et
      hataBildir('seriSonucu._yukle', e, s);
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
    if (ekOdul != null) {
      // reklam ödülü alındı: kazanan 2x, kaybeden sıfıra döndü
      return _kazandim == true
          ? ('+${m.net + ekOdul!}', 'Riva · 2x')
          : ('±0', 'iade alındı');
    }
    return switch (_kazandim) {
      true => ('+${m.net}', 'Riva'),
      false => ('-${m.giris}', 'Riva'),
      null => ('±0', 'iade edildi'),
    };
  }

  // ---------- FAZ 2.20: İSTEĞE BAĞLI ÖDÜLLÜ REKLAM ----------
  // FAZ 2.21: admin limitine bağlı — hak yoksa teklif görünmez.
  bool get _teklifVar => UzakAyar.reklamAcik &&
      !b.dostluk &&
      _kazandim != null &&
      masa != null &&
      ekOdul == null &&
      reklamHak > 0;

  Future<void> _reklamIzle() async {
    if (reklamOynuyor || !_teklifVar) return;
    if (!ReklamServis.destekleniyor) {
      _mesaj('Reklamlar yalnız telefonda (Android/iOS) gösterilir.');
      return;
    }
    setState(() => reklamOynuyor = true);
    try {
      final islem = await ReklamServis.odulluGoster();
      if (islem == null) {
        final neden = ReklamServis.sonHata;
        if (neden != null) hataBildir('seriSonucu._reklamIzle', neden);
        _mesaj(neden == 'reklam ödülden önce kapatıldı'
            ? 'Reklam tamamlanmadı — ödül için sonuna kadar izlemek gerek.'
            : 'Reklam şu an gösterilemedi — birazdan tekrar dene.');
        return;
      }
      final odul = await OnlineServis().macReklamOdul(b.seriId, islem);
      if (mounted) {
        setState(() => ekOdul = odul);
        _mesaj(_kazandim == true
            ? '+$odul Riva daha — kazancın ikiye katlandı!'
            : '+$odul Riva iade edildi — bu seride kaybın yok!');
      }
    } catch (e, s) {
      final m = '$e';
      if (m.contains('tavan')) {
        // ortak günlük limit doldu — kartı da kapat
        if (mounted) setState(() => reklamHak = 0);
        _mesaj('Günlük reklam hakkın doldu — yarın yine gel!');
      } else {
        _mesaj(m.contains('zaten')
            ? 'Bu seri için ödül zaten alınmış.'
            : m.contains('pencere')
                ? 'Ödül süresi doldu (maçtan sonra 1 saat geçerli).'
                : temizMesaj('seriSonucu._reklamOdul', e,
                    'Ödül şu an işlenemedi — birazdan tekrar dene.', s));
      }
    } finally {
      if (mounted) setState(() => reklamOynuyor = false);
    }
  }

  void _mesaj(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
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
    return PopScope(
      // geri tuşu da bir "çıkış": geçiş reklamı kuralı burada da geçerli
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _cikis(() => Navigator.of(context).pop());
      },
      child: Scaffold(
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
              // ── FAZ 2.20: İSTEĞE BAĞLI ÖDÜLLÜ REKLAM TEKLİFİ ──
              if (_teklifVar) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x2830C060), GolrivaColors.card]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: GolrivaColors.ok.withValues(alpha: .45)),
                  ),
                  child: Column(children: [
                    Text(
                        _kazandim == true
                            ? 'KAZANCINI İKİYE KATLA'
                            : 'KAYBINI GERİ AL',
                        style: GoogleFonts.bigShouldersDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: GolrivaColors.ok)),
                    const SizedBox(height: 3),
                    Text(
                        _kazandim == true
                            ? 'Kısa bir reklam izle, +${masa!.net} Riva daha kazan.'
                            : 'Kısa bir reklam izle, ${masa!.giris} Riva girişin geri gelsin.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.figtree(
                            fontSize: 11.5, color: GolrivaColors.dim)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                GolrivaColors.ok.withValues(alpha: .9),
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: reklamOynuyor ? null : _reklamIzle,
                        icon: reklamOynuyor
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.play_circle_outline, size: 19),
                        label: Text(
                            reklamOynuyor
                                ? 'REKLAM YÜKLENİYOR…'
                                : 'REKLAM İZLE (+${_kazandim == true ? masa!.net : masa!.giris} RIVA)',
                            style: GoogleFonts.bigShouldersDisplay(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 15)),
                      ),
                    ),
                  ]),
                ),
              ],
              if (ekOdul != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: kartDekor(r: 16).copyWith(
                      border: Border.all(
                          color: GolrivaColors.ok.withValues(alpha: .5))),
                  child: Row(children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: GolrivaColors.ok),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          _kazandim == true
                              ? '+$ekOdul Riva daha cüzdanında — kazanç ikiye katlandı!'
                              : '+$ekOdul Riva iade edildi — bu seride kaybın sıfır!',
                          style: GoogleFonts.figtree(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GolrivaColors.ok)),
                    ),
                  ]),
                ),
              ],
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
              // ── ANA SAYFA (+ LİG SAYFASI) + PAYLAŞ ──
              // Faz 2.22: lig maçlarında lig sayfasına dönüş butonu.
              Row(children: [
                Expanded(
                  child: goldButon('ANA SAYFA', () {
                    _cikis(() =>
                        Navigator.of(context).popUntil((r) => r.isFirst));
                  }, yazi: ligId != null ? 13 : 15),
                ),
                if (ligId != null &&
                    widget.kanal.ligSayfaKur != null) ...[
                  const SizedBox(width: 9),
                  Expanded(
                    child: goldButon('LİG SAYFASI', () {
                      _cikis(() {
                        final ekran =
                            widget.kanal.ligSayfaKur!(ligId!);
                        final nav = Navigator.of(context);
                        nav.popUntil((r) => r.isFirst);
                        nav.push(
                            MaterialPageRoute(builder: (_) => ekran));
                      });
                    }, yazi: 13),
                  ),
                ],
                const SizedBox(width: 9),
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
                              fontSize: ligId != null ? 13 : 15,
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
              // FAZ 2.24: rakibi şikayet et / engelle (Apple 1.2)
              Center(
                child: TextButton(
                  onPressed: () => kisiModerasyonAc(context, b.rakipAdi),
                  child: Text('${b.rakipAdi} ile bir sorun mu var? BİLDİR',
                      style: const TextStyle(
                          color: GolrivaColors.dim2, fontSize: 11.5)),
                ),
              ),
            ],
          ),
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
