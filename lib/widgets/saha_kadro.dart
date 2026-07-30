import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/golriva_theme.dart';

/// Tek saha slotu.
class SahaSlot {
  final String poz; // K/D/O/F
  final String pozAd; // "Kaleci" — bos slotta gosterilir
  final String? ad; // null = bos
  final String? deger; // "170" / "27,6" / "146" ...
  const SahaSlot(
      {required this.poz, required this.pozAd, this.ad, this.deger});
}

/// SAHA GORUNUMU (kullanici istegi, 30 Tem): kadro futbol sahasi uzerinde —
/// bos mevkiler kesikli daire + mevki adiyla gorunur, secilenler mevkisine
/// yazilir. YUKSEKLIK ICERIKTEN TURETILIR; sabit en-boy orani YOK
/// ("kalecinin skoru dipte kirpildi" dersi — HTML v1'de yasandi).
class SahaKadro extends StatelessWidget {
  final String baslik; // 'SEN · 512 cm'
  final String? sagBilgi; // '4/6'
  final Color renk; // GolrivaColors.p1 / p2
  final List<List<SahaSlot>> siralar; // ustten alta: F, O, D, (K)
  const SahaKadro(
      {super.key,
      required this.baslik,
      required this.renk,
      required this.siralar,
      this.sagBilgi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GolrivaColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GolrivaColors.edge2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(baslik,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    color: renk,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1)),
          ),
          if (sagBilgi != null)
            Text(sagBilgi!,
                style: GoogleFonts.spaceGrotesk(
                    color: GolrivaColors.dim, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF10160F), Color(0xFF0B100B)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x24FFFFFF), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _SahaCizgileri())),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
              child: Column(children: [
                for (var r = 0; r < siralar.length; r++) ...[
                  if (r > 0) const SizedBox(height: 10),
                  Row(children: [
                    for (final slot in siralar[r])
                      Expanded(child: Center(child: _SahaSlotKutusu(slot, renk))),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SahaSlotKutusu extends StatelessWidget {
  final SahaSlot slot;
  final Color renk;
  const _SahaSlotKutusu(this.slot, this.renk);

  @override
  Widget build(BuildContext context) {
    final dolu = slot.ad != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: dolu
            ? BoxDecoration(
                shape: BoxShape.circle, color: renk,
                border: Border.all(color: renk, width: 1.5))
            : null,
        child: dolu
            ? Text(slot.poz,
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF161006)))
            : CustomPaint(
                size: const Size(26, 26),
                painter: _KesikliDaire(),
                child: Center(
                  child: Text(slot.poz,
                      style: GoogleFonts.bigShouldersDisplay(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: GolrivaColors.dim2)),
                ),
              ),
      ),
      const SizedBox(height: 3),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(dolu ? slot.ad! : slot.pozAd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.figtree(
                fontSize: 9.5,
                fontWeight: dolu ? FontWeight.w600 : FontWeight.w400,
                fontStyle: dolu ? FontStyle.normal : FontStyle.italic,
                color: dolu ? GolrivaColors.ink : GolrivaColors.dim2)),
      ),
      SizedBox(
        height: 13,
        child: Text(dolu ? (slot.deger ?? '') : '',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.goldHi)),
      ),
    ]);
  }
}

/// Bos slot: kesikli cember (GOLRIVA kurali: vektorel cizim, hazir ikon yok).
class _KesikliDaire extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x52FFFFFF);
    final merkez = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    const parca = 10;
    for (var i = 0; i < parca; i++) {
      final a1 = (i * 2 * math.pi / parca);
      canvas.drawArc(Rect.fromCircle(center: merkez, radius: r), a1,
          math.pi / parca, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Saha dekoru: serit dokusu + orta cizgi + orta yuvarlak + ceza sahalari.
class _SahaCizgileri extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final serit = Paint()..color = const Color(0x0D5FE08C);
    final bant = size.height / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(
          Rect.fromLTWH(0, i * bant, size.width, bant), serit);
    }
    final cizgi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x21FFFFFF);
    // orta cizgi + yuvarlak
    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), cizgi);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2),
        size.width * .135, cizgi);
    // ceza sahalari (ust/alt)
    final kutu = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0x1AFFFFFF);
    final kw = size.width * .48, kh = size.height * .09;
    canvas.drawRect(
        Rect.fromLTWH((size.width - kw) / 2, 0, kw, kh), kutu);
    canvas.drawRect(
        Rect.fromLTWH((size.width - kw) / 2, size.height - kh, kw, kh), kutu);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
