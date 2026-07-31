/// REKLAM SERVISI — kosullu ihrac:
/// - Android/iOS derlemesi → reklam_mobil.dart (google_mobile_ads)
/// - Web derlemesi → reklam_stub.dart (reklamsiz, guvenli bos davranis)
/// Boylece `flutter build web` google_mobile_ads'in platform kanallarina
/// hic dokunmaz; testler (VM) mobil dosyayi yukler ama Platform kontrolu
/// sayesinde reklam kodu calismaz.
export 'reklam_stub.dart' if (dart.library.io) 'reklam_mobil.dart';
