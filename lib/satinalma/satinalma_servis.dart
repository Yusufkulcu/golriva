/// SATIN ALMA SERVISI — kosullu ihrac:
/// Android/iOS → satinalma_mobil.dart (in_app_purchase),
/// web → satinalma_stub.dart (magaza yok, guvenli bos davranis).
library;

export 'satinalma_stub.dart' if (dart.library.io) 'satinalma_mobil.dart';
