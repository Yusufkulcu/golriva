import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/golriva_theme.dart';
import 'hata_raporu.dart';
import 'online_servis.dart';
import 'supabase_ayar.dart';

/// VERİ İTİRAZI diyalogu — "her itiraz ciddiye alınır" kuralı.
/// Futbolcu adı + açıklama alınır, itiraz_gonder RPC'sine iletilir
/// (sunucu: min 10 karakter, günde 5 itiraz).
Future<void> veriItirazDialog(BuildContext context) async {
  if (!SupabaseAyar.yapilandirildi || !OnlineServis().girisYapildi) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veri itirazı için çevrimiçi hesap gerekli.')));
    return;
  }
  final oyuncu = TextEditingController();
  final mesaj = TextEditingController();
  String? hata;
  bool mesgul = false;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: GolrivaColors.edge)),
        title: Text('VERİ İTİRAZI',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.5,
                color: GolrivaColors.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              'Bir futbolcunun verisi (boy, yaş, kulüp, gol…) yanlış mı? '
              'Bildir, inceleyelim.',
              style: GoogleFonts.figtree(
                  fontSize: 12, color: GolrivaColors.dim)),
          const SizedBox(height: 10),
          TextField(
            controller: oyuncu,
            style:
                GoogleFonts.figtree(fontSize: 14, color: GolrivaColors.ink),
            decoration:
                const InputDecoration(isDense: true, hintText: 'Futbolcu adı'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: mesaj,
            maxLines: 3,
            style:
                GoogleFonts.figtree(fontSize: 14, color: GolrivaColors.ink),
            decoration: const InputDecoration(
                isDense: true,
                hintText: 'Neyin yanlış olduğunu açıkla (en az 10 karakter)'),
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
            onPressed: mesgul
                ? null
                : () async {
                    if (oyuncu.text.trim().isEmpty ||
                        mesaj.text.trim().length < 10) {
                      setD(() => hata =
                          'Futbolcu adı ve en az 10 karakter açıklama gerekli.');
                      return;
                    }
                    setD(() {
                      mesgul = true;
                      hata = null;
                    });
                    try {
                      await OnlineServis()
                          .itirazGonder(oyuncu.text.trim(), mesaj.text.trim());
                      if (c.mounted) {
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'İtirazın alındı — incelenip düzeltilecek. Teşekkürler!')));
                      }
                    } catch (e, s) {
                      setD(() {
                        mesgul = false;
                        hata = '$e'.contains('sınır')
                            ? 'Günlük itiraz sınırına ulaştın (5) — yarın tekrar dene.'
                            : '$e'.contains('kısa')
                                ? 'Açıklama çok kısa — en az 10 karakter yaz.'
                                : temizMesaj('itiraz._gonder', e,
                                    'Gönderilemedi — tekrar dene.', s);
                      });
                    }
                  },
            child: Text(mesgul ? 'GÖNDERİLİYOR…' : 'GÖNDER',
                style: const TextStyle(color: GolrivaColors.goldHi)),
          ),
        ],
      ),
    ),
  );
}
