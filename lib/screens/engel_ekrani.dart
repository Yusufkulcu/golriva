import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../online/hata_raporu.dart';
import '../online/uzak_ayar.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// FAZ 2.30 — AÇILIŞ ENGEL EKRANLARI (uzak ayar):
///  * GÜNCELLEME GEREKLİ: sürüm zorunlu minimumun altında → tek buton,
///    mağazaya götürür; oyuna geçiş yok.
///  * BAKIM: sunucu bakım modunda → mesaj + 'TEKRAR DENE'.
/// Geri tuşu kapalı (kaçış yok) — kural: eski istemci oynamaz.
class EngelEkrani extends StatelessWidget {
  final bool bakim;
  final VoidCallback? tekrarDene;
  const EngelEkrani({super.key, required this.bakim, this.tekrarDene});

  Future<void> _magazayaGit(BuildContext context) async {
    final url = Uri.tryParse(UzakAyar.magazaUrl);
    if (url == null) return;
    try {
      final oldu = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!oldu && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mağaza açılamadı — uygulama mağazasından '
                'GolRiva\'yı güncelle.')));
      }
    } catch (e, s) {
      hataBildir('engel._magazayaGit', e, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SvgPicture.asset('assets/brand/beyin_top.svg',
                    width: 72, height: 72),
                const SizedBox(height: 22),
                goldYazi(bakim ? 'KISA BİR MOLA' : 'GÜNCELLEME GEREKLİ',
                    boyut: 30, bosluk: 2),
                const SizedBox(height: 12),
                Text(
                    bakim
                        ? UzakAyar.bakimMesaj
                        : 'GolRiva\'nın yeni bir sürümü var. Oyuna devam '
                            'etmek için mağazadan güncellemen gerekiyor — '
                            'rakiplerinle aynı kuralları ve aynı verileri '
                            'kullanmak için bu şart.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        fontSize: 13.5,
                        color: GolrivaColors.dim,
                        height: 1.55)),
                if (!bakim) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Sürümün: ${UzakAyar.mevcutSurum} · '
                      'Gerekli: ${UzakAyar.minSurum}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 11, color: GolrivaColors.dim2)),
                ],
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: bakim
                      ? goldButon('TEKRAR DENE', tekrarDene, yazi: 16)
                      : goldButon('MAĞAZADA GÜNCELLE',
                          () => _magazayaGit(context),
                          yazi: 16),
                ),
                if (!bakim && tekrarDene != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: tekrarDene,
                    child: const Text('Güncelledim, tekrar kontrol et',
                        style: TextStyle(
                            color: GolrivaColors.dim, fontSize: 12)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
