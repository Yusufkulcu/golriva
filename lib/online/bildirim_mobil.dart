import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'hata_raporu.dart';
import 'online_servis.dart';
import 'supabase_ayar.dart';

/// Arka planda gelen mesaj (uygulama kapalı/arkada). Sistem bildirimi
/// zaten kendi gösterir; burada ekstra iş yapmıyoruz ama Firebase bu
/// giriş noktasını ister. TOP-LEVEL + vm:entry-point olmak ZORUNDA.
@pragma('vm:entry-point')
Future<void> _arkaPlanMesaji(RemoteMessage mesaj) async {
  // Bilinçli olarak boş: bildirimi işletim sistemi gösterir.
}

/// PUSH BİLDİRİMİ — Firebase Cloud Messaging entegrasyonu.
/// google-services.json / GoogleService-Info.plist YOKSA sessizce kapalı
/// kalır (CI ve yapılandırılmamış derlemeler çökmemeli).
class BildirimServis {
  static final _yerel = FlutterLocalNotificationsPlugin();
  static bool _aktif = false;
  static String? _token;

  static bool get destekleniyor => Platform.isAndroid || Platform.isIOS;

  // TEK TİP bildirim: cihazın varsayılan bildirim sesi/kanalı.
  // (Edge Function ve AndroidManifest ile AYNI kanal kimliği.)
  static const _kanalId = 'golriva_bildirim';
  static const _kanalAd = 'GOLRIVA Bildirimleri';

  static Future<void> baslat() async {
    if (!SupabaseAyar.yapilandirildi || !destekleniyor) return;
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Config dosyaları yok/yanlış → push kapalı, uygulama normal çalışır.
      _aktif = false;
      return;
    }
    _aktif = true;
    try {
      FirebaseMessaging.onBackgroundMessage(_arkaPlanMesaji);
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(); // iOS + Android 13+ izin diyaloğu

      // iOS'ta uygulama ÖNDEYKEN de bildirim + ses göster.
      await fm.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);

      await _kanallariKur();
      await _yerel.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // Öndeyken gelen mesajı elle göster (Android otomatik göstermez).
      FirebaseMessaging.onMessage.listen(_ondeGoster);

      // iOS: FCM jetonu APNs jetonu gelmeden istenirse 'apns-token-not-set'
      // (hata kayıtları) — önce APNs'i kısa aralıklarla bekle (en çok ~5 sn).
      if (Platform.isIOS) {
        for (var i = 0; i < 10; i++) {
          if (await fm.getAPNSToken() != null) break;
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      // Jetonu al + kaydet, yenilenince tekrar kaydet.
      _token = await fm.getToken();
      await _kaydet();
      fm.onTokenRefresh.listen((t) {
        _token = t;
        _kaydet();
      });

      // Giriş/çıkış olduğunda jetonu doğru kullanıcıya bağla.
      Supabase.instance.client.auth.onAuthStateChange.listen((durum) {
        if (durum.event == AuthChangeEvent.signedIn) _kaydet();
      });
    } catch (e, s) {
      hataBildir('bildirim.baslat', e, s);
    }
  }

  static Future<void> _kanallariKur() async {
    final eklenti = _yerel.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (eklenti == null) return;
    // Tek kanal — cihazın varsayılan bildirim sesiyle.
    await eklenti.createNotificationChannel(const AndroidNotificationChannel(
      _kanalId, _kanalAd,
      importance: Importance.high,
    ));
  }

  static void _ondeGoster(RemoteMessage mesaj) {
    final bildirim = mesaj.notification;
    if (bildirim == null) return;
    _yerel.show(
      id: bildirim.hashCode,
      title: bildirim.title,
      body: bildirim.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kanalId, _kanalAd,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> _kaydet() async {
    if (!_aktif || _token == null) return;
    final platform = Platform.isIOS ? 'ios' : 'android';
    await OnlineServis().cihazTokenKaydet(_token!, platform);
  }

  /// Giriş/kayıt sonrası çağrılır — jetonu yeni kullanıcıya bağlar.
  static Future<void> girisSonrasi() => _kaydet();

  /// Çıkışta bu cihazın jetonunu siler.
  static Future<void> cikistaTemizle() async {
    if (!_aktif || _token == null) return;
    await OnlineServis().cihazTokenSil(_token!);
  }
}
