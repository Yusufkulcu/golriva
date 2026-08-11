import 'package:supabase_flutter/supabase_flutter.dart';

/// ARKADAŞ LİGİ servisi (Faz 2.19) — faz2_19_arkadas_ligi.sql RPC'leri.
/// Kurallar sunucuda; istemci salt görüntüler ve niyet bildirir.

class AligOzet {
  final String id, kod, ad, durum;
  final int giris, boyut, uyeSayisi, havuz, benimPuan;
  final DateTime? bitisAt;
  final String? kazanan;
  AligOzet(this.id, this.kod, this.ad, this.durum, this.giris, this.boyut,
      this.uyeSayisi, this.havuz, this.benimPuan, this.bitisAt, this.kazanan);
}

class AligUye {
  final String userId, ad;
  final int puan, oynanan, g, b, m, hukmen;
  final bool aktif;
  AligUye(this.userId, this.ad, this.puan, this.oynanan, this.g, this.b,
      this.m, this.hukmen, this.aktif);
}

class AligMac {
  final String id;
  final int tur;
  final String p1, p2, durum;
  final String? kazanan, seriId;
  final bool hukmen, katilimsiz;
  final DateTime? hazir1At, hazir2At;
  AligMac(this.id, this.tur, this.p1, this.p2, this.durum, this.kazanan,
      this.seriId, this.hukmen, this.katilimsiz, this.hazir1At, this.hazir2At);

  bool oyuncusu(String uid) => uid == p1 || uid == p2;
  String rakip(String uid) => uid == p1 ? p2 : p1;

  /// Rakibin hazır sinyali son 90 sn içinde mi?
  bool rakipHazir(String uid, DateTime sunucuSimdi) {
    final t = uid == p1 ? hazir2At : hazir1At;
    return t != null && sunucuSimdi.difference(t).inSeconds < 90;
  }
}

class AligDetay {
  final String id, kod, ad, durum, kurucu;
  final int giris, boyut, havuz, sureGun;
  final DateTime? bitisAt;
  final String? kazanan;
  final List<String> kazananlar;
  final List<AligUye> uyeler; // puan sıralı
  final List<AligMac> maclar; // tur sıralı
  AligDetay(this.id, this.kod, this.ad, this.durum, this.kurucu, this.giris,
      this.boyut, this.havuz, this.sureGun, this.bitisAt, this.kazanan,
      this.kazananlar, this.uyeler, this.maclar);

  String uyeAdi(String uid) {
    for (final u in uyeler) {
      if (u.userId == uid) return u.ad;
    }
    return '?';
  }
}

/// alig_hazir RPC dönüşü.
class AligHazirDurum {
  final String durum; // bekliyor / oyunda / bitti
  final String? seriId;
  AligHazirDurum(this.durum, this.seriId);
}

class AligServis {
  SupabaseClient get _c => Supabase.instance.client;
  String? get uid => _c.auth.currentUser?.id;

  /// Lig kur → paylaşılacak LIG-XXXX kodu döner.
  Future<String> ligOlustur(
      {required String ad,
      required int giris,
      required int boyut,
      required int sureGun}) async {
    final r = await _c.rpc('alig_olustur', params: {
      'ad_p': ad,
      'giris_p': giris,
      'boyut_p': boyut,
      'sure_p': sureGun,
    });
    return r as String;
  }

  /// Ad ön kontrolü (asıl karar sunucuda — kur anında yine doğrulanır).
  Future<bool> adUygun(String ad) async {
    try {
      final r = await _c.rpc('alig_ad_uygun', params: {'t': ad});
      return r == true;
    } catch (_) {
      return true; // ağ hatasında kurma denemesi sunucuda reddedilir
    }
  }

  Future<void> ligKatil(String kod) =>
      _c.rpc('alig_katil', params: {'k': kod.trim()});

  Future<void> ligAyril(String ligId) =>
      _c.rpc('alig_ayril', params: {'lid': ligId});

  /// HAZIRIM sinyali (90 sn canlı) — bekleme yoklaması da bunu çağırır:
  /// her çağrı kendi sinyalimi tazeler VE maç başladıysa seri kimliğini verir.
  Future<AligHazirDurum> ligHazir(String macId) async {
    final r = await _c.rpc('alig_hazir', params: {'mid': macId});
    final m = Map<String, dynamic>.from(r as Map);
    return AligHazirDurum(m['durum'] as String, m['seri_id'] as String?);
  }

  Future<List<AligOzet>> liglerim() async {
    final r = await _c.rpc('aliglerim');
    return [
      for (final x in (r as List))
        AligOzet(
          x['id'] as String,
          x['kod'] as String,
          x['ad'] as String,
          x['durum'] as String,
          (x['giris'] as num).toInt(),
          (x['boyut'] as num).toInt(),
          (x['uye_sayisi'] as num).toInt(),
          (x['havuz'] as num).toInt(),
          (x['benim_puan'] as num).toInt(),
          x['bitis_at'] == null
              ? null
              : DateTime.parse(x['bitis_at'] as String),
          x['kazanan'] as String?,
        )
    ];
  }

  Future<AligDetay> ligDetay(String ligId) async {
    final l = await _c
        .from('arkadas_ligleri')
        .select()
        .eq('id', ligId)
        .single();
    final uyelerR = await _c
        .from('alig_uyeler')
        .select()
        .eq('lig_id', ligId);
    final maclarR = await _c
        .from('alig_maclar')
        .select()
        .eq('lig_id', ligId)
        .order('tur', ascending: true);
    final uids = [
      for (final u in (uyelerR as List)) u['user_id'] as String
    ];
    final adlarR = await _c
        .from('profiller')
        .select('id, kullanici_adi')
        .inFilter('id', uids);
    final adlar = {
      for (final p in (adlarR as List))
        p['id'] as String: p['kullanici_adi'] as String
    };
    final uyeler = [
      for (final u in uyelerR)
        AligUye(
          u['user_id'] as String,
          adlar[u['user_id']] ?? '?',
          (u['puan'] as num).toInt(),
          (u['oynanan'] as num).toInt(),
          (u['g'] as num).toInt(),
          (u['b'] as num).toInt(),
          (u['m'] as num).toInt(),
          (u['hukmen'] as num).toInt(),
          (u['aktif'] as bool?) ?? true,
        )
    ]..sort((a, b) {
        final p = b.puan.compareTo(a.puan);
        if (p != 0) return p;
        final h = a.hukmen.compareTo(b.hukmen);
        if (h != 0) return h;
        return a.ad.compareTo(b.ad);
      });
    final maclar = [
      for (final m in (maclarR as List))
        AligMac(
          m['id'] as String,
          (m['tur'] as num).toInt(),
          m['p1'] as String,
          m['p2'] as String,
          m['durum'] as String,
          m['kazanan'] as String?,
          m['seri_id'] as String?,
          (m['hukmen'] as bool?) ?? false,
          (m['katilimsiz'] as bool?) ?? false,
          m['hazir1_at'] == null
              ? null
              : DateTime.parse(m['hazir1_at'] as String),
          m['hazir2_at'] == null
              ? null
              : DateTime.parse(m['hazir2_at'] as String),
        )
    ];
    return AligDetay(
      l['id'] as String,
      l['kod'] as String,
      l['ad'] as String,
      l['durum'] as String,
      l['kurucu'] as String,
      (l['giris'] as num).toInt(),
      (l['boyut'] as num).toInt(),
      (l['havuz'] as num).toInt(),
      (l['sure_gun'] as num).toInt(),
      l['bitis_at'] == null ? null : DateTime.parse(l['bitis_at'] as String),
      l['kazanan'] as String?,
      [
        if (l['kazananlar'] is List)
          for (final k in (l['kazananlar'] as List)) k as String
      ],
      uyeler,
      maclar,
    );
  }
}
