import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../screens/ana_iskelet.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'hata_raporu.dart';
import 'online_servis.dart';

/// İLK AÇILIŞ / HESAP EKRANI — kullanıcı kuralı: uygulama doğrudan ana
/// sayfaya girmez. GİRİŞ · KAYIT OL · MİSAFİR; ayrıca ŞİFREMİ UNUTTUM
/// (e-postaya gelen 6 haneli kodla yeni şifre).
class AuthEkrani extends StatefulWidget {
  final GolrivaRepos repos;
  const AuthEkrani({super.key, required this.repos});

  @override
  State<AuthEkrani> createState() => _AuthEkraniState();
}

enum _Adim { giris, kayit, unuttum, kod, kullaniciAdi }

class _AuthEkraniState extends State<AuthEkrani> {
  final servis = OnlineServis();
  _Adim adim = _Adim.giris;
  final eposta = TextEditingController();
  final sifre = TextEditingController();
  final sifre2 = TextEditingController();
  final kod = TextEditingController();
  final kullaniciAdi = TextEditingController();
  final referans = TextEditingController();
  String? hata, bilgi;
  bool mesgul = false;

  @override
  void dispose() {
    for (final c in [eposta, sifre, sifre2, kod, kullaniciAdi, referans]) {
      c.dispose();
    }
    super.dispose();
  }

  void _gec(_Adim a) => setState(() {
        adim = a;
        hata = null;
        bilgi = null;
      });

  /// Oturum acildi: profil varsa ana sayfa, yoksa kullanici adi secimi.
  Future<void> _oturumSonrasi() async {
    final p = await servis.profilGetir();
    if (!mounted) return;
    if (p == null) {
      _gec(_Adim.kullaniciAdi);
    } else {
      _anaSayfa();
    }
  }

  void _anaSayfa() => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => AnaIskelet(repos: widget.repos)));

  Future<void> _calistir(Future<void> Function() is_) async {
    setState(() {
      mesgul = true;
      hata = null;
    });
    try {
      await is_();
    } catch (e, s) {
      final m = '$e';
      if (mounted) {
        setState(() => hata = e is String
            ? e // bilerek firlatilan kullanici mesaji (dogrulama)
            : m.contains('Invalid login')
                ? 'E-posta ya da şifre hatalı.'
                : m.contains('already registered')
                    ? 'Bu e-posta zaten kayıtlı — GİRİŞ YAP\'ı dene.'
                    : m.contains('least 6')
                        ? 'Şifre en az 6 karakter olmalı.'
                        : m.contains('invalid') && m.contains('otp')
                            ? 'Kod hatalı ya da süresi dolmuş.'
                            : m.contains('duplicate') || m.contains('23505')
                                ? 'Bu kullanıcı adı alınmış — başka bir tane dene.'
                                : temizMesaj('auth._calistir', e,
                                    'İşlem şu an tamamlanamadı — tekrar dene.', s));
      }
    } finally {
      if (mounted) setState(() => mesgul = false);
    }
  }

  Future<void> _giris() => _calistir(() async {
        await servis.epostaGiris(eposta.text.trim(), sifre.text);
        await _oturumSonrasi();
      });

  Future<void> _kayit() => _calistir(() async {
        if (sifre.text != sifre2.text) throw 'Şifreler aynı değil.';
        if (kullaniciAdi.text.trim().length < 3 ||
            kullaniciAdi.text.trim().length > 14) {
          throw 'Kullanıcı adı 3-14 karakter olmalı.';
        }
        final sonuc =
            await servis.epostaKayit(eposta.text.trim(), sifre.text);
        if (sonuc == 'onay') {
          _gec(_Adim.giris);
          setState(() => bilgi =
              'Onay e-postası gönderildi — kutunu kontrol et, onaylayıp giriş yap.');
          return;
        }
        await servis.profilOlustur(kullaniciAdi.text.trim());
        await _referansUygula();
        if (mounted) _anaSayfa();
      });

  /// İsteğe bağlı referans kodu — profil açıldıktan SONRA denenir,
  /// başarısızlık girişi asla engellemez (sonuç SnackBar ile bildirilir).
  Future<void> _referansUygula() async {
    final k = referans.text.trim();
    if (k.isEmpty || !mounted) return;
    String mesaj;
    try {
      final odul = await servis.referansKullan(k);
      mesaj = odul > 0
          ? 'Referans kodu uygulandı: +$odul RIVA'
          : 'Referans kodu kaydedildi';
    } catch (e, s) {
      final m = '$e';
      mesaj = m.contains('geçersiz')
          ? 'Referans kodu geçersiz — hesabın yine de açıldı'
          : m.contains('zaten')
              ? 'Bu hesapta referans kodu zaten kullanılmış'
              : temizMesaj('auth._referans', e,
                  'Referans kodu şu an uygulanamadı.', s);
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mesaj)));
    }
  }

  Future<void> _misafir() => _calistir(() async {
        await servis.misafirGiris();
        await _oturumSonrasi();
      });

  Future<void> _kodGonder() => _calistir(() async {
        await servis.sifreKoduGonder(eposta.text.trim());
        _gec(_Adim.kod);
        setState(() =>
            bilgi = 'E-postana 6 haneli kod gönderildi (gelmezse spam kutusuna bak).');
      });

  Future<void> _sifreYenile() => _calistir(() async {
        await servis.sifreSifirla(
            eposta.text.trim(), kod.text, sifre.text);
        await _oturumSonrasi();
      });

  Future<void> _adKaydet() => _calistir(() async {
        final ad = kullaniciAdi.text.trim();
        if (ad.length < 3 || ad.length > 14) {
          throw 'Kullanıcı adı 3-14 karakter olmalı.';
        }
        await servis.profilOlustur(ad);
        await _referansUygula();
        if (mounted) _anaSayfa();
      });

  // ── ARAYÜZ ──

  Widget _kutu(TextEditingController c, String ipucu,
          {bool gizli = false, TextInputType? tip}) =>
      Padding(
        padding: const EdgeInsets.only(top: 9),
        child: TextField(
          controller: c,
          obscureText: gizli,
          keyboardType: tip,
          autocorrect: false,
          style: GoogleFonts.figtree(fontSize: 14, color: GolrivaColors.ink),
          decoration: InputDecoration(hintText: ipucu, isDense: true),
        ),
      );

  Widget _baslikSatir(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s,
            textAlign: TextAlign.center,
            style: GoogleFonts.bigShouldersDisplay(
                fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            children: [
              // marka
              SvgPicture.asset('assets/brand/beyin_top.svg',
                  width: 72, height: 72),
              const SizedBox(height: 10),
              Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  goldYazi('GOL', boyut: 34),
                  Text('RIVA',
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: GolrivaColors.ink)),
                ]),
              ),
              Center(
                child: Text('FUTBOL ZEKÂSI DÜELLOSU',
                    style: GoogleFonts.figtree(
                        fontSize: 10,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                        color: GolrivaColors.dim)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: gKartDekor(r: 22),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _adimIcerik()),
              ),
              if (bilgi != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(bilgi!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 12, color: GolrivaColors.ok)),
                ),
              if (hata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(hata!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 12, color: GolrivaColors.bad)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _adimIcerik() {
    switch (adim) {
      case _Adim.giris:
        return [
          _baslikSatir('GİRİŞ YAP'),
          _kutu(eposta, 'E-posta', tip: TextInputType.emailAddress),
          _kutu(sifre, 'Şifre', gizli: true),
          const SizedBox(height: 12),
          goldButon(mesgul ? '…' : 'GİRİŞ YAP', mesgul ? null : _giris,
              yazi: 16),
          TextButton(
              onPressed: () => _gec(_Adim.unuttum),
              child: const Text('Şifremi unuttum',
                  style: TextStyle(color: GolrivaColors.dim, fontSize: 12))),
          const Divider(color: GolrivaColors.edge2),
          OutlinedButton(
              onPressed: mesgul ? null : () => _gec(_Adim.kayit),
              child: Text('KAYIT OL',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: GolrivaColors.goldHi))),
          const SizedBox(height: 6),
          OutlinedButton(
              onPressed: mesgul ? null : _misafir,
              child: Text('MİSAFİR OLARAK OYNA',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: GolrivaColors.dim))),
          const SizedBox(height: 4),
          Text('Misafir hesabı bu cihaza bağlıdır — silinirse ilerleme kaybolur.',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                  fontSize: 10, color: GolrivaColors.dim2)),
        ];
      case _Adim.kayit:
        return [
          _baslikSatir('KAYIT OL'),
          _kutu(kullaniciAdi, 'Kullanıcı adı (3-14)'),
          _kutu(eposta, 'E-posta', tip: TextInputType.emailAddress),
          _kutu(sifre, 'Şifre (en az 6)', gizli: true),
          _kutu(sifre2, 'Şifre (tekrar)', gizli: true),
          _kutu(referans, 'Referans kodu (isteğe bağlı)'),
          const SizedBox(height: 12),
          goldButon(mesgul ? '…' : 'HESAP AÇ · +500 RIVA',
              mesgul ? null : _kayit,
              yazi: 15),
          TextButton(
              onPressed: () => _gec(_Adim.giris),
              child: const Text('← Girişe dön',
                  style: TextStyle(color: GolrivaColors.dim, fontSize: 12))),
        ];
      case _Adim.unuttum:
        return [
          _baslikSatir('ŞİFREMİ UNUTTUM'),
          Text('E-postana 6 haneli doğrulama kodu göndereceğiz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                  fontSize: 12, color: GolrivaColors.dim)),
          _kutu(eposta, 'E-posta', tip: TextInputType.emailAddress),
          const SizedBox(height: 12),
          goldButon(mesgul ? '…' : 'KOD GÖNDER', mesgul ? null : _kodGonder,
              yazi: 15),
          TextButton(
              onPressed: () => _gec(_Adim.giris),
              child: const Text('← Girişe dön',
                  style: TextStyle(color: GolrivaColors.dim, fontSize: 12))),
        ];
      case _Adim.kod:
        return [
          _baslikSatir('YENİ ŞİFRE'),
          _kutu(kod, 'E-postadaki 6 haneli kod',
              tip: TextInputType.number),
          _kutu(sifre, 'Yeni şifre (en az 6)', gizli: true),
          const SizedBox(height: 12),
          goldButon(mesgul ? '…' : 'ŞİFREYİ YENİLE',
              mesgul ? null : _sifreYenile,
              yazi: 15),
          TextButton(
              onPressed: () => _gec(_Adim.unuttum),
              child: const Text('Kod gelmedi mi? Tekrar gönder',
                  style: TextStyle(color: GolrivaColors.dim, fontSize: 12))),
        ];
      case _Adim.kullaniciAdi:
        return [
          _baslikSatir('KULLANICI ADINI SEÇ'),
          Text('Rakiplerin seni bu adla görecek · +500 RIVA hediye',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                  fontSize: 12, color: GolrivaColors.dim)),
          _kutu(kullaniciAdi, 'Kullanıcı adı (3-14)'),
          _kutu(referans, 'Referans kodu (isteğe bağlı)'),
          const SizedBox(height: 12),
          goldButon(mesgul ? '…' : 'BAŞLA', mesgul ? null : _adKaydet,
              yazi: 16),
        ];
    }
  }
}
