import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'data/repos.dart';
import 'online/auth_ekrani.dart';
import 'online/bildirim_servis.dart';
import 'online/hata_raporu.dart';
import 'online/online_servis.dart';
import 'online/supabase_ayar.dart';
import 'online/uzak_ayar.dart';
import 'satinalma/satinalma_servis.dart';
import 'screens/acilis_ekrani.dart';
import 'screens/ana_iskelet.dart';
import 'screens/engel_ekrani.dart';
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
  // FAZ 2.30: UZAK AYARLAR — zorunlu minimum sürüm + açma/kapama anahtarları.
  // Sürüm PackageInfo'dan; sunucu okunamazsa varsayılanlar (kilitlenmez).
  try {
    final bilgi = await PackageInfo.fromPlatform();
    UzakAyar.mevcutSurum = bilgi.version;
    uygulamaSurumu = '${bilgi.version}+${bilgi.buildNumber}'; // hata raporu etiketi
  } catch (e, s) {
    hataBildir('main.packageInfo', e, s);
  }
  await UzakAyar.yukle();
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
  // SATIN ALMA (iOS inceleme düzeltmesi): mağaza akışı AÇILIŞTA dinlenir —
  // yarım kalan StoreKit/Play işlemleri burada teslim edilir ve sunucuya
  // işlenir (benzersiz işlem kimliği: çift ödül imkânsız).
  SatinAlmaServis.onArkaPlanSatinAlma = (urunKodu, islemId) async {
    final servis = OnlineServis();
    if (!servis.girisYapildi) return;
    try {
      final odul = await servis.satinAlmaOdul(
          SatinAlmaServis.magaza, urunKodu, islemId);
      mesajKey.currentState?.showSnackBar(
          SnackBar(content: Text('+$odul RIVA cüzdanına işlendi.')));
    } catch (e, s) {
      // aynı işlem ikinci kez teslim edildiyse benzersiz kısıt (23505)
      // fırlar — bu NORMALDİR, çift ödül engellendi demektir
      final m = '$e';
      if (!m.contains('23505') && !m.contains('duplicate')) {
        hataBildir('satinalma.arkaPlan', e, s);
      }
    }
  };
  SatinAlmaServis.baslat();
  // OTURUM KURALI: oturum hangi yoldan kapanirsa kapansin (cikis, hesap
  // silme, baska cihazdan atilma) uygulama KOKE doner; kok girise yonlendirir.
  if (SupabaseAyar.yapilandirildi) {
    OnlineServis().cikisiDinle(() {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
    });
  }
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
  bool? profilVar; // çevrimiçi: oturum açıkken profil var mı (null = kontrol sürüyor)

  @override
  void initState() {
    super.initState();
    GolrivaRepos.load().then((r) {
      if (mounted) setState(() => repos = r);
    }, onError: (e, StackTrace s) {
      hataBildir('main._Loader', e as Object, s);
      if (mounted) setState(() => hata = e);
    });
    // OTURUM KURALI (kullanıcı isteği): oturum yoksa YA DA oturum var ama
    // profil tamamlanmamışsa uygulama ekranları AÇILMAZ — giriş/kayıt gelir.
    if (SupabaseAyar.yapilandirildi && OnlineServis().girisYapildi) {
      OnlineServis().profilGetir().then((p) {
        if (mounted) setState(() => profilVar = p != null);
      }, onError: (Object e, StackTrace s) {
        hataBildir('main._profilKontrol', e, s);
        if (mounted) setState(() => profilVar = false); // şüphede: girişe
      });
    }
  }

  /// FAZ 2.30: bakım/güncelleme ekranındaki 'tekrar dene' — uzak ayarları
  /// yeniden okur; engel kalktıysa normal akış sürer.
  Future<void> _uzakYenile() async {
    await UzakAyar.yukle();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // FAZ 2.30 — AÇILIŞ KAPILARI: bakım modu ve zorunlu minimum sürüm.
    // Eski istemci oynamaz (yeni oyun/kural yayınlarında bozuk kalmasın).
    if (UzakAyar.bakimModu) {
      return EngelEkrani(bakim: true, tekrarDene: _uzakYenile);
    }
    if (UzakAyar.surumEski) {
      return EngelEkrani(bakim: false, tekrarDene: _uzakYenile);
    }
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
    final oturumBeklemede = SupabaseAyar.yapilandirildi &&
        OnlineServis().girisYapildi &&
        profilVar == null;
    if (repos == null || oturumBeklemede) {
      return const AcilisEkrani(); // marka sahnesi (screens/acilis_ekrani.dart)
    }
    // ILK ACILIS KURALI: cevrimici yapida oturum yoksa YA DA profil
    // tamamlanmamissa once Giris/Kayit/Misafir ekrani (kullanici istegi).
    // Cevrimdisi derleme (Supabase yapilandirilmamis) dogrudan iskelete gider.
    if (SupabaseAyar.yapilandirildi &&
        (!OnlineServis().girisYapildi || profilVar == false)) {
      return AuthEkrani(repos: repos!);
    }
    return AnaIskelet(repos: repos!);
  }
}
