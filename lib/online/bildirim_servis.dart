// PUSH BİLDİRİMİ servisi — web-güvenli koşullu içe aktarma.
// Web derlemesinde stub (hiçbir şey yapmaz); Android/iOS'ta gerçek Firebase.
export 'bildirim_stub.dart' if (dart.library.io) 'bildirim_mobil.dart';
