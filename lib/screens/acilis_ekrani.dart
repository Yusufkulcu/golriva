import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/golriva_theme.dart';

/// AÇILIŞ EKRANI — marka sahnesi.
/// Karanlık stadyum fonu: köşelerden sızan projektör ışıltıları + zeminde
/// soluk orta saha çizgisi motifi. Beyin-top elastik büyüyerek gelir ve
/// nabız gibi ışıldar; GOL ile RIVA iki yandan kayarak birleşir; slogan
/// aşağıdan süzülür; altta akan altın yükleme çizgisi döner.
/// Veri/oturum hazır olana kadar _Loader tarafından gösterilir.
class AcilisEkrani extends StatefulWidget {
  const AcilisEkrani({super.key});

  @override
  State<AcilisEkrani> createState() => _AcilisEkraniState();
}

class _AcilisEkraniState extends State<AcilisEkrani>
    with TickerProviderStateMixin {
  late final AnimationController _giris = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..forward();
  late final AnimationController _dongu = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  Animation<double> _aralik(double a, double b,
          {Curve c = Curves.easeOutCubic}) =>
      CurvedAnimation(parent: _giris, curve: Interval(a, b, curve: c));

  @override
  void dispose() {
    _giris.dispose();
    _dongu.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoS = _aralik(0, .45, c: Curves.elasticOut);
    final golA = _aralik(.25, .60);
    final rivaA = _aralik(.35, .70);
    final sloganA = _aralik(.55, .85);
    final cizgiA = _aralik(.70, 1);
    return Scaffold(
      backgroundColor: GolrivaColors.bg,
      body: Stack(children: [
        // projektör ışıltıları (statik, çok soluk — rahatsız etmez)
        Positioned(top: -140, left: -100, child: _isilti(340, .10)),
        Positioned(top: -70, right: -150, child: _isilti(380, .06)),
        // zemin: orta saha çizgisi motifi (ekran altından taşan çember)
        const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 230,
            child: CustomPaint(painter: _SahaMotifi())),
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // logo — elastik giriş + nabızlı altın ışıma
                AnimatedBuilder(
                  animation: Listenable.merge([logoS, _dongu]),
                  builder: (_, __) {
                    final t =
                        (math.sin(_dongu.value * math.pi * 2) + 1) / 2;
                    return Transform.scale(
                      scale: logoS.value.clamp(0.0, 1.15).toDouble(),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: GolrivaColors.gold
                                    .withValues(alpha: .16 + .16 * t),
                                blurRadius: 55 + 25 * t,
                                spreadRadius: 6),
                          ],
                        ),
                        child: SvgPicture.asset('assets/brand/beyin_top.svg',
                            width: 112, height: 112),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 26),
                // GOL | RIVA — iki yandan kayarak birleşir
                AnimatedBuilder(
                  animation: _giris,
                  builder: (_, __) =>
                      Row(mainAxisSize: MainAxisSize.min, children: [
                    Transform.translate(
                      offset: Offset(-38 * (1 - golA.value), 0),
                      child: Opacity(
                        opacity: golA.value.clamp(0.0, 1.0).toDouble(),
                        child: ShaderMask(
                          shaderCallback: (b) =>
                              GolrivaColors.goldGradient.createShader(b),
                          child: Text('GOL', style: _marka(Colors.white)),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(38 * (1 - rivaA.value), 0),
                      child: Opacity(
                        opacity: rivaA.value.clamp(0.0, 1.0).toDouble(),
                        child: Text('RIVA', style: _marka(GolrivaColors.ink)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
                // slogan — aşağıdan süzülür
                AnimatedBuilder(
                  animation: sloganA,
                  builder: (_, __) => Opacity(
                    opacity: sloganA.value.clamp(0.0, 1.0).toDouble(),
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - sloganA.value)),
                      child: Text('FUTBOL ZEKÂSI DÜELLOSU',
                          style: GoogleFonts.figtree(
                              fontSize: 11,
                              letterSpacing: 4.5,
                              fontWeight: FontWeight.w700,
                              color: GolrivaColors.dim)),
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                // akan altın yükleme çizgisi
                AnimatedBuilder(
                  animation: Listenable.merge([cizgiA, _dongu]),
                  builder: (_, __) => Opacity(
                      opacity: cizgiA.value.clamp(0.0, 1.0).toDouble(),
                      child: _akanCizgi(_dongu.value)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  TextStyle _marka(Color renk) => GoogleFonts.bigShouldersDisplay(
      fontSize: 44,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
      color: renk);

  Widget _isilti(double boyut, double alfa) => IgnorePointer(
        child: Container(
          width: boyut,
          height: boyut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              GolrivaColors.gold.withValues(alpha: alfa),
              Colors.transparent,
            ]),
          ),
        ),
      );

  Widget _akanCizgi(double t) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          width: 132,
          height: 3,
          child: Stack(children: [
            const Positioned.fill(
                child: ColoredBox(color: GolrivaColors.card2)),
            Positioned(
              left: -44 + 176 * t,
              top: 0,
              bottom: 0,
              child: Container(
                width: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    GolrivaColors.goldHi,
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Ekranın altından taşan soluk "orta saha" motifi: büyük çember + orta
/// nokta + yatay çizgi. Çok düşük alfa — fark edilir ama bağırmaz.
class _SahaMotifi extends CustomPainter {
  const _SahaMotifi();

  @override
  void paint(Canvas c, Size s) {
    final kalem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x16D4AF37);
    final merkez = Offset(s.width / 2, s.height + 60);
    c.drawCircle(merkez, 150, kalem);
    c.drawCircle(merkez, 8, kalem);
    c.drawLine(Offset(0, s.height - 30), Offset(s.width, s.height - 30),
        kalem..color = const Color(0x0FD4AF37));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
