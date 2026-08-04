import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/repos.dart';
import 'online/auth_ekrani.dart';
import 'online/bildirim_servis.dart';
import 'online/hata_raporu.dart';
import 'online/online_servis.dart';
import 'online/supabase_ayar.dart';
import 'screens/ana_iskelet.dart';
import 'theme/golriva_theme.dart';

/// Sayfa donuslerini dinlemek icin (sekmeler donuste kendini tazeler).
final rotaGozcusu = RouteObserver<ModalRoute<void>>();

/// Global gezinme + snackbar anahtarlari (ornegin baska cihazdan giris
/// yapilinca herhangi bir ekrandan cikis yaptirmak icin).
final navigatorKey = GlobalKey<NavigatorState>();
final mesajKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FAZ 2: Supabase yalnizca --dart-define ile yapilandirildiysa baslar;
  // aksi halde uygulama tamamen cevrimdisi (hot-seat) calisir.
  await OnlineServis.baslat();
  // FAZ 2.8: yakalanmamis TUM hatalar admin'e raporlanir (kullanici gormez).
  FlutterError.onError = (d) {
    FlutterError.presentError(d); // gelistirici konsolu icin
    hataBildir('global.flutter', d.exception, d.stack);
  };
  PlatformDispatcher.instance.onError = (e, s) {
    hataBildir('global.platform', e, s);
    return true; // uygulamayi dusurme
  };
  // FAZ 2.9: push bildirimi (Firebase config yoksa sessizce kapali kalir).
  await BildirimServis.baslat();
  runApp(const GolrivaApp());
}

class GolrivaApp extends StatelessWidget {
  const GolrivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GOLRIVA',
      debugShowCheckedModeBanner: false,
      theme: GolrivaTheme.dark(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: mesajKey,
      navigatorObservers: [rotaGozcusu],
      home: const _Loader(),
    );
  }
}

/// Tum veri setlerini paralel yukler (9 JSON, ~5 MB).
class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  GolrivaRepos? repos;
  Object? hata;

  @override
  void initState() {
    super.initState();
    GolrivaRepos.load().then((r) {
      if (mounted) setState(() => repos = r);
    }, onError: (e, StackTrace s) {
      hataBildir('main._Loader', e as Object, s);
      if (mounted) setState(() => hata = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hata != null) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Veriler yüklenemedi. Lütfen uygulamayı kapatıp tekrar aç.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    if (repos == null) {
      // ACILIS EKRANI — K1 Beyin-Top + marka (veri yuklenirken)
      return Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SvgPicture.asset('assets/brand/beyin_top.svg',
                width: 96, height: 96),
            const SizedBox(height: 18),
            RichText(
              text: TextSpan(
                style: GoogleFonts.bigShouldersDisplay(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
                children: const [
                  TextSpan(
                      text: 'GOL',
                      style: TextStyle(color: GolrivaColors.gold)),
                  TextSpan(
                      text: 'RIVA',
                      style: TextStyle(color: GolrivaColors.ink)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('FUTBOL ZEKÂSI DÜELLOSU',
                style: GoogleFonts.figtree(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                    color: GolrivaColors.dim)),
            const SizedBox(height: 26),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: GolrivaColors.gold, strokeWidth: 2.5),
            ),
          ]),
        ),
      );
    }
    // ILK ACILIS KURALI: cevrimici yapida oturum yoksa once
    // Giris/Kayit/Misafir ekrani (kullanici istegi). Cevrimdisi derleme
    // (Supabase yapilandirilmamis) dogrudan ana iskelete gider.
    if (SupabaseAyar.yapilandirildi && !OnlineServis().girisYapildi) {
      return AuthEkrani(repos: repos!);
    }
    return AnaIskelet(repos: repos!);
  }
}
