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
