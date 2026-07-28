import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// GOLRIVA tasarim dili — tasarim/golriva_ekranlar_v1.html'den birebir.
/// Kural: GOL her zaman altin; sol yari (beyin) her zaman altin.
class GolrivaColors {
  static const bg = Color(0xFF08080B);
  static const bg2 = Color(0xFF0E0E13);
  static const card = Color(0xFF14141B);
  static const card2 = Color(0xFF1A1A23);
  static const gold = Color(0xFFD4AF37);
  static const goldHi = Color(0xFFF0D67C);
  static const goldDeep = Color(0xFFA8842A);
  static const ink = Color(0xFFF5F2E9);
  static const dim = Color(0xFFB9B9C6);
  static const dim2 = Color(0xFF8A8A99);
  static const p1 = Color(0xFFE8C35A); // sen — altin
  static const p2 = Color(0xFF7FB4FF); // rakip — buz mavisi
  static const ok = Color(0xFF5FE08C);
  static const bad = Color(0xFFFF7A6E);
  static const edge = Color(0x2ED4AF37); // altin %18
  static const edge2 = Color(0x0FFFFFFF); // beyaz %6

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldHi, gold, goldDeep],
    stops: [0.0, 0.55, 1.0],
  );
}

class GolrivaTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GolrivaColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: GolrivaColors.gold,
        secondary: GolrivaColors.goldHi,
        surface: GolrivaColors.card,
        error: GolrivaColors.bad,
      ),
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        // Basliklar: Big Shoulders Display (atletik condensed)
        displayLarge: GoogleFonts.bigShouldersDisplay(
            fontWeight: FontWeight.w900, letterSpacing: 1.5, color: GolrivaColors.ink),
        displayMedium: GoogleFonts.bigShouldersDisplay(
            fontWeight: FontWeight.w900, letterSpacing: 1.2, color: GolrivaColors.ink),
        titleLarge: GoogleFonts.bigShouldersDisplay(
            fontWeight: FontWeight.w800, letterSpacing: 1.5, color: GolrivaColors.ink),
        // Rakamlar: Space Grotesk
        headlineMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700, color: GolrivaColors.goldHi),
        // Govde: Figtree
        bodyLarge: GoogleFonts.figtree(color: GolrivaColors.ink),
        bodyMedium: GoogleFonts.figtree(color: GolrivaColors.ink),
        bodySmall: GoogleFonts.figtree(color: GolrivaColors.dim),
        labelLarge: GoogleFonts.figtree(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: GolrivaColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GolrivaColors.edge2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GolrivaColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: GolrivaColors.edge, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: GolrivaColors.edge, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: GolrivaColors.gold, width: 1.5),
        ),
        hintStyle: GoogleFonts.figtree(color: GolrivaColors.dim2),
      ),
    );
  }
}
