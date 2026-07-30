import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_ayar.dart';

/// Cevrimici profil ozeti.
class OnlineProfil {
  final String kullaniciAdi;
  final int elo;
  final String ligKod;
  final int bakiye;
  OnlineProfil(this.kullaniciAdi, this.elo, this.ligKod, this.bakiye);
}

/// Masa bilgisi (masalar tablosundan).
class Masa {
  final String kod;
  final int giris;
  final int girisBo3;
  final int minBakiyeKilit;
  Masa(this.kod, this.giris, this.girisBo3, this.minBakiyeKilit);
}

/// Eslesme sonucu.
class EslesmeSonucu {
  final String seriId;
  final String rakipAdi;
  final String oyunKodu; // ilk macin RASTGELE oyunu — sunucu secti
  final String mod;
  EslesmeSonucu(this.seriId, this.rakipAdi, this.oyunKodu, this.mod);
}

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
      // ignore: deprecated_member_use
      await Supabase.initialize(
          url: SupabaseAyar.url, anonKey: SupabaseAyar.anahtar);
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
        .select('kullanici_adi, elo, lig_kod')
        .eq('id', uid!)
        .maybeSingle();
    if (p == null) return null;
    final c = await _c
        .from('cuzdanlar')
        .select('bakiye')
        .eq('user_id', uid!)
        .maybeSingle();
    return OnlineProfil(p['kullanici_adi'] as String, (p['elo'] as num).toInt(),
        p['lig_kod'] as String, ((c?['bakiye'] ?? 0) as num).toInt());
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

  /// Eslesme dongusu adimi: once sunucuda eslesmeyi dene, olmadiysa
  /// baskasinin bizi eslestirmis olabilecegini kontrol et (seriler).
  Future<EslesmeSonucu?> eslesmeKontrol() async {
    final sid = await _c.rpc('eslesme_dene');
    final seri = sid != null
        ? await _c.from('seriler').select().eq('id', sid).maybeSingle()
        : await _c
            .from('seriler')
            .select()
            .or('p1.eq.$uid,p2.eq.$uid')
            .eq('durum', 'oyunda')
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
        .select('oyun_kodu')
        .eq('seri_id', seri['id'])
        .eq('seri_sira', 1)
        .maybeSingle();
    return EslesmeSonucu(
        seri['id'] as String,
        (rakip?['kullanici_adi'] ?? '?') as String,
        (mac?['oyun_kodu'] ?? '?') as String,
        seri['mod'] as String);
  }
}
