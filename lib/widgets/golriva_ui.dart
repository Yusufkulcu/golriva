import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/golriva_theme.dart';

/// golriva_ekranlar_v1.html tasarim setinin ORTAK parcalari —
/// kartlar, altin gradyan yazi, ikonlar, hap etiketler, ilerleme cubugu.

/// .card: duz kart
BoxDecoration kartDekor({double r = 18}) => BoxDecoration(
      gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GolrivaColors.card2, GolrivaColors.card]),
      border: Border.all(color: GolrivaColors.edge2),
      borderRadius: BorderRadius.circular(r),
    );

/// .gcard: altin isiltili kart
BoxDecoration gKartDekor({double r = 18}) => BoxDecoration(
      gradient: const RadialGradient(
          center: Alignment(0, -1.2),
          radius: 1.6,
          colors: [Color(0x21D4AF37), Color(0x0514141B)]),
      color: GolrivaColors.card,
      border: Border.all(color: GolrivaColors.edge),
      borderRadius: BorderRadius.circular(r),
    );

/// .goldtxt: altin gradyanli yazi
Widget goldYazi(String s, {required double boyut, double bosluk = 1.5}) =>
    ShaderMask(
      shaderCallback: (b) => GolrivaColors.goldGradient.createShader(b),
      child: Text(s,
          style: GoogleFonts.bigShouldersDisplay(
              fontSize: boyut,
              fontWeight: FontWeight.w900,
              letterSpacing: bosluk,
              color: Colors.white)),
    );

/// assets/icons/*.svg — tasarim setindeki cizimler
Widget gIkon(String ad, double boyut, [Color renk = GolrivaColors.gold]) =>
    SvgPicture.asset('assets/icons/$ad.svg',
        width: boyut,
        height: boyut,
        colorFilter: ColorFilter.mode(renk, BlendMode.srcIn));

/// avatar dairesi — [url] verilirse fotograf, yoksa bas harf
Widget avatar(String ad, double boyut,
        {Color kenar = GolrivaColors.goldDeep,
        double kalinlik = 1.5,
        String? url}) =>
    Container(
      width: boyut,
      height: boyut,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
            center: Alignment(-.4, -.4),
            colors: [Color(0xFF2B2B35), Color(0xFF17171E)]),
        border: Border.all(color: kenar, width: kalinlik),
        image: url == null
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: url != null
          ? null
          : Text(ad.isEmpty ? '?' : ad[0].toUpperCase(),
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: boyut * .42,
                  fontWeight: FontWeight.w900,
                  color: GolrivaColors.ink)),
    );

/// altin ilerleme cubugu
Widget ilerleme(double oran, {double yukseklik = 5}) => ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: oran.clamp(0, 1),
        minHeight: yukseklik,
        backgroundColor: GolrivaColors.card2,
        valueColor: const AlwaysStoppedAnimation(GolrivaColors.gold),
      ),
    );

/// Turkce buyuk harf (i→İ, ı→I) — Dart toUpperCase locale bilmez.
String trBuyuk(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// kucuk etiket yazisi (9px, genis harf araligi)
Widget etiket(String s, {Color renk = GolrivaColors.dim}) => Text(s,
    style: GoogleFonts.figtree(
        fontSize: 9,
        letterSpacing: 2,
        fontWeight: FontWeight.w700,
        color: renk));

/// buyuk altin dolgulu buton (HIZLI DUELLO stili)
Widget goldButon(String s, VoidCallback? onTap,
        {String? ikonAd, double yazi = 19}) =>
    Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: GolrivaColors.goldGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x48D4AF37), blurRadius: 26, offset: Offset(0, 10))
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            alignment: Alignment.center,
            // FittedBox: uzun basliklar dar ekranda kuculerek sigar
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (ikonAd != null) ...[
                  gIkon(ikonAd, 17, const Color(0xFF231A04)),
                  const SizedBox(width: 8),
                ],
                Text(s,
                    style: GoogleFonts.bigShouldersDisplay(
                        fontSize: yazi,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                        color: const Color(0xFF231A04))),
              ]),
            ),
          ),
        ),
      ),
    );

/// ───────────── YÜKLEME ÖRTÜSÜ ─────────────
/// Kullanıcı kuralı: veri gelmeden sayfa "yarım" görünmesin. Yüklenirken
/// içerik hafifçe bulanır ve ortada küçük bir ilerleme halkası döner; veri
/// gelince 250 ms'de yumuşakça netleşir. Kısa yüklemelerde bulanıklık daha
/// tam oluşmadan söner — rahatsız edici bir "flaş" oluşmaz. Yüklenirken
/// dokunuşlar da engellenir (yarım veriyle işlem yapılamaz).
class YuklemeOrtusu extends StatelessWidget {
  final bool yukleniyor;
  final Widget child;
  const YuklemeOrtusu(
      {super.key, required this.yukleniyor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.passthrough, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: yukleniyor ? 3.0 : 0),
        duration: const Duration(milliseconds: 250),
        builder: (_, s, c) => s <= .05
            ? c!
            : ImageFiltered(
                imageFilter: ImageFilter.blur(
                    sigmaX: s, sigmaY: s, tileMode: TileMode.decal),
                child: c),
        child: child,
      ),
      Positioned.fill(
        child: IgnorePointer(
          ignoring: !yukleniyor,
          child: AnimatedOpacity(
            opacity: yukleniyor ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: ColoredBox(
              color: GolrivaColors.bg.withValues(alpha: .30),
              child: const Center(
                child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        color: GolrivaColors.gold, strokeWidth: 2.6)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// ───────────── SIRA GÖSTERGESİ (çevrimiçi sıra-tabanlı oyunlar) ─────────────
/// Kullanıcı kuralı: sıranın kimde olduğu ekrana bakar bakmaz anlaşılmalı.
/// Sıra sende: altın dolgulu, nabız gibi atan şerit. Sıra rakipte: soluk,
/// sakin şerit + dönen bekleme simgesi. [notu]: "draft kuralı gereği üst üste
/// oynanıyor" gibi özel durum açıklamaları için ikinci satır.
class SiraSeridi extends StatefulWidget {
  final bool siraBende;
  final String rakipAdi;
  final String? notu;
  const SiraSeridi(
      {super.key, required this.siraBende, required this.rakipAdi, this.notu});

  @override
  State<SiraSeridi> createState() => _SiraSeridiState();
}

class _SiraSeridiState extends State<SiraSeridi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nabiz = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 850))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _nabiz.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bende = widget.siraBende;
    return AnimatedBuilder(
      animation: _nabiz,
      builder: (_, __) {
        final t = bende ? _nabiz.value : 0.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            gradient: bende ? GolrivaColors.goldGradient : null,
            color: bende ? null : GolrivaColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: bende ? GolrivaColors.goldHi : GolrivaColors.edge2),
            boxShadow: bende
                ? [
                    BoxShadow(
                        color: const Color(0xFFD4AF37)
                            .withValues(alpha: .22 + .30 * t),
                        blurRadius: 14 + 10 * t)
                  ]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (!bende) ...[
                  const SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GolrivaColors.dim)),
                  const SizedBox(width: 8),
                ],
                Text(
                    bende
                        ? 'SIRA SENDE — OYNA!'
                        : 'SIRA RAKİPTE · ${trBuyuk(widget.rakipAdi)} OYNUYOR',
                    style: GoogleFonts.bigShouldersDisplay(
                        fontSize: bende ? 19 : 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: bende
                            ? const Color(0xFF231A04)
                            : GolrivaColors.dim)),
              ]),
            ),
            if (widget.notu != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(widget.notu!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: bende
                            ? const Color(0xCC231A04)
                            : GolrivaColors.dim2)),
              ),
          ]),
        );
      },
    );
  }
}

/// Taraf vurgusu: sıra hangi taraftaysa o panel tam görünür ve renkli
/// çerçeveyle hafifçe parlar; diğer taraf soluklaşır (kullanıcı kuralı:
/// sıra bir bakışta anlaşılsın). Oyun bitince iki taraf da normale döner.
Widget tarafVurgu(
        {required bool aktif,
        required bool oyunBitti,
        required Color renk,
        required Widget child}) =>
    AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: (aktif && !oyunBitti)
            ? [BoxShadow(color: renk.withValues(alpha: .35), blurRadius: 12)]
            : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: (oyunBitti || aktif) ? 1 : .45,
        child: child,
      ),
    );

/// seri noktalari (BO3 · oo o)
Widget seriNoktalari(List<int?> sonuclar, {String? on, String? arka}) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      if (on != null) ...[
        Text(on,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: GolrivaColors.dim)),
        const SizedBox(width: 6),
      ],
      for (final s in sonuclar)
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: s == 0
                ? GolrivaColors.p1
                : s == 1
                    ? GolrivaColors.p2
                    : GolrivaColors.card2,
            border: Border.all(
                color: s == 0
                    ? GolrivaColors.p1
                    : s == 1
                        ? GolrivaColors.p2
                        : GolrivaColors.edge2),
          ),
        ),
      if (arka != null) ...[
        const SizedBox(width: 6),
        Text(arka,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: GolrivaColors.dim)),
      ],
    ]);
