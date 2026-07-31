import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';
import 'ligler_ekrani.dart';

/// KILAVUZ — oyun kurallari DEGIL; uygulamanin isleyisi:
/// Elo, Riva, lig, masalar, rulet, dostluk, reklam/paketler, adalet.
class KilavuzEkrani extends StatelessWidget {
  const KilavuzEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('KILAVUZ',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            _bolum('ikon:simsek', 'NASIL OYNANIR?',
                'MAÇ BUL de, sistem sana yakın güçte bir rakip bulsun. Hangi '
                'oyunun çıkacağını RULET seçer — kimse önden plan yapamaz, iki '
                'taraf da aynı anda öğrenir. Maçlar sıra tabanlıdır; süre '
                'dolarsa el yanar. Tek maç ya da 3 maçlık seri (Bo3) '
                'oynayabilirsin.'),
            _bolum('ikon:nav_siralama', 'ELO NEDİR?',
                'Elo, gücünü ölçen puandır (herkes 1000\'den başlar). Maç '
                'kazanınca artar, kaybedince azalır; senden güçlü birini '
                'yenmek daha çok puan getirir. Eşleştirme Elo\'ya göre '
                'yapılır — yani rakiplerin hep kendi seviyende olur. '
                'Elo satın alınamaz, sadece kazanılır.'),
            _bolum('ikon:riva', 'RIVA NEDİR?',
                'Riva, oyun içi paradır. Ranked maça girerken masa girişi '
                'ödenir; kazanan ödülü alır. Kazanma yolları: hoş geldin '
                'hediyesi (+500), düello kazanmak, günde 10 kez ödüllü reklam '
                'izlemek (+50) ve paketler. Riva YALNIZ oyun girişinde '
                'kullanılır — Elo ya da lig satın alınamaz.'),
            _bolum('ikon:kupa_kucuk', 'LİG SİSTEMİ',
                'Elo eşleştirir, lig ödüllendirir. Seri kazandıkça lig puanı '
                'toplar, eşiğe ulaşınca terfi edersin (Amatör → Şampiyonlar '
                'Ligi, 7 kademe). Üst liglerde mağlubiyet puan düşürür; puan '
                'sıfırın altına inerse küme düşersin. Berabere seride puan '
                'işlemez.', ekstra: _ligButonu(context)),
            _bolum('ikon:onay', 'MASALAR',
                'ÇAYLAK (50) · KLASİK (100) · YÜKSEK (250) · ELİT (500) — '
                'sayılar tek maç girişidir, Bo3 girişleri daha yüksektir. '
                'Yüksek masalar belirli bir bakiyeye ulaşınca açılır '
                '(kilitli masaya dokunup nedenini görebilirsin). Kazanan, '
                'iki girişin toplamından küçük bir kesinti (rake) düşülmüş '
                'ödülü alır; berabere kalırsan girişin iade edilir.'),
            _bolum('ikon:nav_duellolar', 'ARKADAŞLA & DOSTLUK MAÇI',
                'Arkadaşını kullanıcı adıyla ekleyebilir, sıralamada '
                'arkadaş filtresiyle yarışabilirsin. DAVET KUR ile GLR-XXXX '
                'kodu oluştur, arkadaşın KODLA KATIL desin — uzaktan dostluk '
                'maçı başlar. Dostluk maçında Riva alınmaz, Elo işlemez. '
                'Aynı cihazda sırayla (hot-seat) da oynayabilirsiniz.'),
            _bolum('ikon:oynat', 'REKLAM & PAKETLER',
                'Cüzdandan günde 10 kez ödüllü reklam izleyip her seferinde '
                '+50 Riva kazanabilirsin. Acelen varsa Riva paketleri satın '
                'alınabilir. Unutma: para sana güç değil, sadece oyun hakkı '
                'alır — kazanmak bilgiyle olur.'),
            _bolum('ikon:carpi', 'ADALET & VERİ',
                'İki oyuncu da aynı soruları aynı sırada görür — kurulumu '
                'sunucu belirler, kimse avantaj alamaz. Maçtan kaçan hükmen '
                'kaybeder. Futbolcu verilerinde hata görürsen maç sonunda '
                'VERİ İTİRAZI ile bildir; her itiraz incelenir.'),
            const SizedBox(height: 8),
            Text('GOLRIVA · Futbol Zekâsı Düellosu',
                textAlign: TextAlign.center,
                style: GoogleFonts.figtree(
                    fontSize: 10, color: GolrivaColors.dim2)),
          ],
        ),
      ),
    );
  }

  Widget _ligButonu(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LiglerEkrani())),
          child: const Text('LİG MERDİVENİNİ GÖR →',
              style: TextStyle(color: GolrivaColors.goldHi, fontSize: 12)),
        ),
      );

  Widget _bolum(String ikon, String baslik, String metin, {Widget? ekstra}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: kartDekor(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            gIkon(ikon.split(':').last, 16, GolrivaColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(baslik,
                  style: GoogleFonts.bigShouldersDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(metin,
              style: GoogleFonts.figtree(
                  fontSize: 12.5, color: GolrivaColors.dim, height: 1.55)),
          if (ekstra != null) ekstra,
        ]),
      );
}
