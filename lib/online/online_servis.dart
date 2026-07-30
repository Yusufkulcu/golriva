import 'package:supabase_flutter/supabase_flutter.dart';
import 'mac_kanali.dart';
import 'supabase_ayar.dart';

/// Cevrimici profil ozeti.
class OnlineProfil {
  final String kullaniciAdi;
  final int elo;
  final String ligKod;
  final int ligPuan;
  final int bakiye;
  final DateTime? uyelik;
  OnlineProfil(this.kullaniciAdi, this.elo, this.ligKod, this.ligPuan,
      this.bakiye, this.uyelik);
}

/// Masa bilgisi (masalar tablosundan).
class Masa {
  final String kod;
  final int giris;
  final int girisBo3;
  final int minBakiyeKilit;
  Masa(this.kod, this.giris, this.girisBo3, this.minBakiyeKilit);
}

// (Eslesme sonucu artik OnlineMacBilgi olarak doner — mac_kanali.dart)

/// Supabase erisim katmani. SADECE SupabaseAyar.yapilandirildi ise kullanilir;
/// tum oyun mantigi sunucuda (SECURITY DEFINER RPC), istemciye guvenilmez.
class OnlineServis {
  SupabaseClient get _c => Supabase.instance.client;

  static Future<void> baslat() async {
    if (!SupabaseAyar.yapilandirildi) return;
    if (SupabaseAyar.yeniAnahtarSistemi) {
      // Yeni API anahtarlari (sb_publishable_...)
      await Supabase.initialize(
          url: SupabaseAyar.url, publishableKey: SupabaseAyar.anahtar);
    } else {
      // Eski "anon public" JWT anahtarlari (geriye uyumluluk)
      await Supabase.initialize(
          url: SupabaseAyar.url,
          // ignore: deprecated_member_use
          anonKey: SupabaseAyar.anahtar);
    }
  }

  bool get girisYapildi =>
      SupabaseAyar.yapilandirildi && _c.auth.currentUser != null;
  String? get uid => _c.auth.currentUser?.id;

  /// Misafir oturumu (Supabase panelinde "Anonymous sign-ins" ACIK olmali).
  Future<void> misafirGiris() async {
    if (_c.auth.currentUser == null) await _c.auth.signInAnonymously();
  }

  /// Kayit: misafir oturum + profil/cuzdan/500 RIVA (yeni_kullanici RPC).
  /// Kullanici adi doluysa PostgrestException firlatir (23505).
  Future<void> kayitOl(String kullaniciAdi) async {
    await misafirGiris();
    await _c.rpc('yeni_kullanici',
        params: {'u': uid, 'ad': kullaniciAdi});
  }

  Future<OnlineProfil?> profilGetir() async {
    if (!girisYapildi) return null;
    final p = await _c
        .from('profiller')
        .select('kullanici_adi, elo, lig_kod, lig_puan, created_at')
        .eq('id', uid!)
        .maybeSingle();
    if (p == null) return null;
    final c = await _c
        .from('cuzdanlar')
        .select('bakiye')
        .eq('user_id', uid!)
        .maybeSingle();
    return OnlineProfil(
        p['kullanici_adi'] as String,
        (p['elo'] as num).toInt(),
        p['lig_kod'] as String,
        ((p['lig_puan'] ?? 0) as num).toInt(),
        ((c?['bakiye'] ?? 0) as num).toInt(),
        p['created_at'] == null
            ? null
            : DateTime.parse(p['created_at'] as String));
  }

  Future<List<Masa>> masalar() async {
    final r = await _c
        .from('masalar')
        .select('kod, giris, giris_bo3, min_bakiye_kilit')
        .eq('aktif', true)
        .order('giris');
    return (r as List)
        .map((m) => Masa(m['kod'] as String, (m['giris'] as num).toInt(),
            (m['giris_bo3'] as num).toInt(),
            (m['min_bakiye_kilit'] as num).toInt()))
        .toList();
  }

  /// Ranked kuyruk — oyun SECILMEZ, sunucu rulet cevirir (kullanici kurali).
  Future<void> kuyrugaGir(String mod, String masaKod) =>
      _c.rpc('kuyruga_gir', params: {'md': mod, 'masa': masaKod});

  Future<void> kuyruktanCik() => _c.rpc('kuyruktan_cik');

  /// Sunucu "simdi"si — kuyruk alt siniri ve senkron islerinde kullanilir.
  Future<DateTime?> sunucuSaati() async {
    try {
      final r = await _c.rpc('sunucu_saati');
      return DateTime.parse(r as String);
    } catch (_) {
      return null;
    }
  }

  /// TERK EDILMIS acik maclarimi hukmen kapat: son hamlesi (yoksa mac
  /// baslangici) 3 dk'dan eskiyse terk eden benim demektir → rakip kazanir.
  /// (Kullanici kurali: oyundan/uygulamadan cikan otomatik maglup.)
  /// Ayrica bu, eski serilerin "hayalet eslesme" olarak donmesini de bitirir.
  Future<void> terkEdilmisleriKapat() async {
    if (!girisYapildi) return;
    try {
      final seriler = await _c
          .from('seriler')
          .select('id, p1, p2')
          .or('p1.eq.$uid,p2.eq.$uid')
          .eq('durum', 'oyunda');
      final esik = DateTime.now().toUtc().subtract(const Duration(minutes: 3));
      for (final s in (seriler as List)) {
        final mac = await _c
            .from('maclar')
            .select('id, created_at')
            .eq('seri_id', s['id'])
            .eq('durum', 'oyunda')
            .maybeSingle();
        if (mac == null) continue;
        final sonHamle = await _c
            .from('hamleler')
            .select('sunucu_ts')
            .eq('mac_id', mac['id'])
            .order('id', ascending: false)
            .limit(1)
            .maybeSingle();
        final sonTs = DateTime.parse(
            (sonHamle?['sunucu_ts'] ?? mac['created_at']) as String);
        if (sonTs.isBefore(esik)) {
          final rakip = s['p1'] == uid ? s['p2'] : s['p1'];
          await _c.rpc('mac_bitir',
              params: {'mid': mac['id'], 'kazanan_p': rakip});
        }
      }
    } catch (_) {
      // temizlik firsatcidir; hata sessizce yutulur
    }
  }

  /// SIRALAMA: Elo'ya gore ilk 50 + benim siram.
  Future<(List<(String, int)>, int?)> siralama() async {
    final r = await _c
        .from('profiller')
        .select('kullanici_adi, elo')
        .order('elo', ascending: false)
        .limit(50);
    final liste = (r as List)
        .map((p) => (p['kullanici_adi'] as String, (p['elo'] as num).toInt()))
        .toList();
    int? benimSiram;
    if (girisYapildi) {
      final ben = await _c
          .from('profiller')
          .select('elo')
          .eq('id', uid!)
          .maybeSingle();
      if (ben != null) {
        final ustum = await _c
            .from('profiller')
            .count()
            .gt('elo', (ben['elo'] as num).toInt());
        benimSiram = ustum + 1;
      }
    }
    return (liste, benimSiram);
  }

  /// PROFIL ISTATISTIGI: seri sayisi, galibiyet %, oyun bazinda kazanma.
  Future<({int seri, int galibiyet, Map<String, (int, int)> oyunlar})>
      istatistik() async {
    if (!girisYapildi) return (seri: 0, galibiyet: 0, oyunlar: {});
    final seriler = await _c
        .from('seriler')
        .select('id, kazanan')
        .or('p1.eq.$uid,p2.eq.$uid')
        .eq('durum', 'bitti');
    final ids = (seriler as List).map((s) => s['id'] as String).toList();
    final toplam = ids.length;
    final kazandigim =
        seriler.where((s) => s['kazanan'] == uid).length;
    final oyunlar = <String, (int, int)>{}; // kod → (kazanilan, toplam)
    if (ids.isNotEmpty) {
      final maclar = await _c
          .from('maclar')
          .select('oyun_kodu, kazanan')
          .inFilter('seri_id', ids)
          .eq('durum', 'bitti');
      for (final m in (maclar as List)) {
        final k = m['oyun_kodu'] as String;
        final o = oyunlar[k] ?? (0, 0);
        oyunlar[k] = (o.$1 + (m['kazanan'] == uid ? 1 : 0), o.$2 + 1);
      }
    }
    return (
      seri: toplam,
      galibiyet: toplam == 0 ? 0 : (100 * kazandigim / toplam).round(),
      oyunlar: oyunlar,
    );
  }

  /// DUELLOLAR: son seriler (rakip adi, skor, kazandim mi, tarih, mod).
  Future<List<({String rakip, int s1, int s2, bool? kazandim, String mod,
      DateTime tarih, bool benP1})>> macGecmisi() async {
    if (!girisYapildi) return [];
    final r = await _c
        .from('seriler')
        .select('p1, p2, skor1, skor2, kazanan, mod, created_at, durum')
        .or('p1.eq.$uid,p2.eq.$uid')
        .eq('durum', 'bitti')
        .order('created_at', ascending: false)
        .limit(30);
    final sonuc = <({String rakip, int s1, int s2, bool? kazandim, String mod,
        DateTime tarih, bool benP1})>[];
    for (final s in (r as List)) {
      final benP1 = s['p1'] == uid;
      final rakipId = benP1 ? s['p2'] : s['p1'];
      final rp = await _c
          .from('profiller')
          .select('kullanici_adi')
          .eq('id', rakipId)
          .maybeSingle();
      sonuc.add((
        rakip: (rp?['kullanici_adi'] ?? '?') as String,
        s1: (s['skor1'] as num).toInt(),
        s2: (s['skor2'] as num).toInt(),
        kazandim: s['kazanan'] == null ? null : s['kazanan'] == uid,
        mod: s['mod'] as String,
        tarih: DateTime.parse(s['created_at'] as String),
        benP1: benP1,
      ));
    }
    return sonuc;
  }

  /// Eslesme dongusu adimi: once sunucuda eslesmeyi dene, olmadiysa
  /// baskasinin bizi eslestirmis olabilecegini kontrol et (seriler).
  /// [seriAltSiniri]: SADECE bu andan sonra kurulan seriler kabul edilir —
  /// kuyruga giris ani verilir; eski/yarim seriler ASLA eslesme sayilmaz
  /// (kullanici kurali: hayalet eslesme hicbir kosulda olmayacak).
  Future<OnlineMacBilgi?> eslesmeKontrol({DateTime? seriAltSiniri}) async {
    final sid = await _c.rpc('eslesme_dene');
    final esik = (seriAltSiniri ??
            DateTime.now().toUtc().subtract(const Duration(minutes: 10)))
        .toIso8601String();
    final seri = sid != null
        ? await _c.from('seriler').select().eq('id', sid).maybeSingle()
        : await _c
            .from('seriler')
            .select()
            .or('p1.eq.$uid,p2.eq.$uid')
            .eq('durum', 'oyunda')
            .gte('created_at', esik)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
    if (seri == null) return null;
    final rakipId = seri['p1'] == uid ? seri['p2'] : seri['p1'];
    final rakip = await _c
        .from('profiller')
        .select('kullanici_adi')
        .eq('id', rakipId)
        .maybeSingle();
    final mac = await _c
        .from('maclar')
        .select('id, oyun_kodu, seed, created_at')
        .eq('seri_id', seri['id'])
        .eq('durum', 'oyunda')
        .order('seri_sira', ascending: false)
        .limit(1)
        .maybeSingle();
    if (mac == null) return null;
    return OnlineMacBilgi(
      macId: mac['id'] as String,
      seriId: seri['id'] as String,
      oyunKodu: mac['oyun_kodu'] as String,
      seed: (mac['seed'] as num).toInt(),
      baslangic: DateTime.parse(mac['created_at'] as String),
      p1Uid: seri['p1'] as String,
      p2Uid: seri['p2'] as String,
      benimSiram: seri['p1'] == uid ? 0 : 1,
      rakipAdi: (rakip?['kullanici_adi'] ?? '?') as String,
      mod: seri['mod'] as String,
      masaKod: (seri['masa_kod'] ?? '') as String,
    );
  }

  /// Herkese acik profil ozeti (VS ekrani: rakibin elo + ligi).
  Future<({String ad, int elo, String ligKod})?> kamuProfil(
      String hedefUid) async {
    final p = await _c
        .from('profiller')
        .select('kullanici_adi, elo, lig_kod')
        .eq('id', hedefUid)
        .maybeSingle();
    if (p == null) return null;
    return (
      ad: p['kullanici_adi'] as String,
      elo: (p['elo'] as num).toInt(),
      ligKod: p['lig_kod'] as String,
    );
  }

  /// Serideki maclar (sirali): VS ekrani seri noktalari + seri sonucu
  /// "Oyunlar: X ✓ · Y ✗" listesi icin.
  Future<List<({String oyunKodu, String? kazananUid, String durum})>>
      seriMaclari(String seriId) async {
    final r = await _c
        .from('maclar')
        .select('oyun_kodu, kazanan, durum, seri_sira')
        .eq('seri_id', seriId)
        .order('seri_sira', ascending: true);
    return (r as List)
        .map((m) => (
              oyunKodu: m['oyun_kodu'] as String,
              kazananUid: m['kazanan'] as String?,
              durum: m['durum'] as String,
            ))
        .toList();
  }

  /// Masanin giris ucreti + kazanana NET odul (mod'a gore).
  Future<({int giris, int net})?> masaOdul(String masaKod, String mod) async {
    if (masaKod.isEmpty) return null;
    final m = await _c
        .from('masalar')
        .select('giris, giris_bo3, kazanan_net, kazanan_net_bo3')
        .eq('kod', masaKod)
        .maybeSingle();
    if (m == null) return null;
    final bo3 = mod == 'bo3';
    return (
      giris: ((bo3 ? m['giris_bo3'] : m['giris']) as num).toInt(),
      net: ((bo3 ? m['kazanan_net_bo3'] : m['kazanan_net']) as num).toInt(),
    );
  }
}
