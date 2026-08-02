import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/golriva_theme.dart';
import 'hata_raporu.dart';
import 'online_servis.dart';

/// Misafir kayit: kullanici adi sec (3-14) → profil + 500 RIVA hos geldin.
class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final ctrl = TextEditingController();
  String? hata;
  bool mesgul = false;

  Future<void> _kaydol() async {
    final ad = ctrl.text.trim();
    if (ad.length < 3 || ad.length > 14) {
      setState(() => hata = 'Kullanıcı adı 3-14 karakter olmalı');
      return;
    }
    setState(() {
      mesgul = true;
      hata = null;
    });
    try {
      await OnlineServis().kayitOl(ad);
      if (mounted) Navigator.pop(context, true);
    } catch (e, s) {
      setState(() {
        mesgul = false;
        hata = '$e'.contains('duplicate') || '$e'.contains('23505')
            ? 'Bu kullanıcı adı alınmış — başka bir tane dene'
            : temizMesaj('kayit._kaydet', e,
                'Kayıt şu an tamamlanamadı — tekrar dene.', s);
      });
    }
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('ÇEVRİMİÇİ HESAP',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Text('Bir kullanıcı adı seç — hesabın misafir olarak açılır, '
                'hoş geldin hediyesi olarak 500 RIVA yüklenir.',
                style: GoogleFonts.figtree(
                    fontSize: 13, color: GolrivaColors.dim)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLength: 14,
              enabled: !mesgul,
              decoration: const InputDecoration(
                  hintText: 'Kullanıcı adı (3-14)', counterText: ''),
            ),
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
              onPressed: mesgul ? null : _kaydol,
              child: mesgul
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('HESABI AÇ · +500 RIVA',
                      style: GoogleFonts.bigShouldersDisplay(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}
