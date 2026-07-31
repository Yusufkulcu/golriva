import 'dart:typed_data';
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
  final String? avatarUrl;
  OnlineProfil(this.kullaniciAdi, this.elo, this.ligKod, this.ligPuan,
      this.bakiye, this.uyelik, this.avatarUrl);
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
        .select('kullanici_adi, elo, lig_kod, lig_puan, created_at, avatar_url')
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
            : DateTime.parse(p['created_at'] as String),
        p['avatar_url'] as String?);
  }

  // ---------- FAZ 2.6: HESAP (e-posta + şifre) ----------

  String? get eposta => _c.auth.currentUser?.email;
  bool get misafirMi => _c.auth.currentUser?.isAnonymous ?? false;

  /// E-posta + şifre ile kayıt. Oturum hemen açılmadıysa (Supabase'de
  /// "Confirm email" AÇIK demektir) 'onay' döner; kullanıcı e-postasını
  /// onaylayıp GİRİŞ yapmalıdır. null = oturum açık, devam.
  Future<String?> epostaKayit(String email, String sifre) async {
    final r = await _c.auth.signUp(email: email, password: sifre);
    return r.session == null ? 'onay' : null;
  }

  Future<void> epostaGiris(String email, String sifre) async {
    await _c.auth.signInWithPassword(email: email, password: sifre);
  }

  /// Şifre sıfırlama kodu gönder (e-posta şablonunda {{ .Token }} olmalı).
  Future<void> sifreKoduGonder(String email) =>
      _c.auth.resetPasswordForEmail(email);

  /// E-postadaki 6 haneli kodla yeni şifre belirle.
  Future<void> sifreSifirla(String email, String kod, String yeniSifre) async {
    await _c.auth
        .verifyOTP(type: OtpType.recovery, token: kod.trim(), email: email);
    await _c.auth.updateUser(UserAttributes(password: yeniSifre));
  }

  Future<void> cikisYap() => _c.auth.signOut();

  /// Oturum acikken profil olustur (kullanici adi sec) — 500 RIVA hediye.
  Future<void> profilOlustur(String ad) =>
      _c.rpc('yeni_kullanici', params: {'u': uid, 'ad': ad});

  // ---------- FAZ 2.6: PROFİL FOTOĞRAFI ----------

  /// JPEG baytlarini Storage'a yukle (uid.jpg, uzerine yazar), profili
  /// guncelle; onbellek kirici ?v= ile herkese acik URL doner.
  Future<String> avatarYukle(Uint8List bytes) async {
    final yol = '$uid.jpg';
    await _c.storage.from('avatarlar').uploadBinary(yol, bytes,
        fileOptions:
            const FileOptions(upsert: true, contentType: 'image/jpeg'));
    final url = _c.storage.from('avatarlar').getPublicUrl(yol);
    await _c.rpc('avatar_ayarla', params: {'u': url});
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // ---------- FAZ 2.6: SATIN ALMA ----------

  /// Magaza satin alimini sunucuya bildir; Riva miktari doner.
  /// (magaza, islem_id) benzersiz — ayni islem iki kez odullenmez.
  Future<int> satinAlmaOdul(
      String magaza, String urunKodu, String islemId) async {
    final r = await _c.rpc('satin_alma_odul', params: {
      'magaza_adi': magaza,
      'urun_kodu': urunKodu,
      'islem_id': islemId
    });
    return (r as num).toInt();
  }

  /// Satistaki Riva paketleri (urunler tablosu — admin panelden yonetilir).
  Future<List<({String kod, String ad, int riva})>> urunler() async {
    final r = await _c
        .from('urunler')
        .select('kod, ad, riva')
        .eq('aktif', true)
        .order('sira');
    return (r as List)
        .map((u) => (
              kod: u['kod'] as String,
              ad: u['ad'] as String,
              riva: (u['riva'] as num).toInt(),
            ))
        .toList();
  }

  // ---------- FAZ 2.6: VERİ İTİRAZI ----------

  Future<void> itirazGonder(String oyuncuAdi, String mesaj) =>
      _c.rpc('itiraz_gonder', params: {'oyuncu': oyuncuAdi, 'm': mesaj});

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
    if (!girisYapildi) {
      return (seri: 0, galibiyet: 0, oyunlar: <String, (int, int)>{});
    }
    final seriler = await _c
        .from('seriler')
        .select('id, kazanan')
        .or('p1.eq.$uid,p2.eq.$uid')
        .eq('durum', 'bitti')
        .eq('dostluk', false); // performans RANKED maclardan olculur
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
            .eq('dostluk', false) // ranked arama dostluk serisini almaz
            .gte('created_at', esik)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
    if (seri == null) return null;
    return _bilgiKur(seri);
  }

  /// Seri satirindan OnlineMacBilgi kur (rakip adi + acik mac sorgulanir).
  Future<OnlineMacBilgi?> _bilgiKur(Map<String, dynamic> seri) async {
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
      dostluk: (seri['dostluk'] ?? false) as bool,
    );
  }

  /// Seri id'sinden mac bilgisi (davet akisi: katilan + kurucu kullanir).
  Future<OnlineMacBilgi?> seridenBilgi(String seriId) async {
    final seri =
        await _c.from('seriler').select().eq('id', seriId).maybeSingle();
    if (seri == null) return null;
    return _bilgiKur(seri);
  }

  // ---------- FAZ 2.4: ARKADAŞLAR ----------

  Future<void> arkadasEkle(String ad) =>
      _c.rpc('arkadas_ekle', params: {'ad': ad.trim()});

  Future<void> arkadasSil(String ad) =>
      _c.rpc('arkadas_sil', params: {'ad': ad});

  Future<List<({String ad, int elo, String ligKod})>> arkadasListesi() async {
    final r = await _c.rpc('arkadas_listesi');
    return (r as List)
        .map((p) => (
              ad: p['kullanici_adi'] as String,
              elo: (p['elo'] as num).toInt(),
              ligKod: p['lig_kod'] as String,
            ))
        .toList();
  }

  // ---------- FAZ 2.4: HAFTALIK SIRALAMA ----------

  /// Son 7 gunde kazanilan ranked seri sayisina gore ilk 50.
  Future<List<(String, int)>> haftalikSiralama() async {
    final r = await _c.rpc('haftalik_siralama');
    return (r as List)
        .map((p) =>
            (p['kullanici_adi'] as String, (p['sayi'] as num).toInt()))
        .toList();
  }

  // ---------- FAZ 2.4: DAVET KODU (uzaktan dostluk maci) ----------

  /// Davet kur; GLR-XXXX kodu doner. [oyunKodu] null = rulet.
  Future<String> davetOlustur(String mod, String? oyunKodu) async {
    final r = await _c
        .rpc('davet_olustur', params: {'md': mod, 'oyun': oyunKodu});
    return r as String;
  }

  /// Koda katil; kurulan dostluk serisinin mac bilgisi doner.
  Future<OnlineMacBilgi?> davetKatil(String kod) async {
    final sid = await _c.rpc('davet_katil', params: {'k': kod});
    return seridenBilgi(sid as String);
  }

  /// Kurucu yoklamasi: davet eslesti mi? Eslestiyse mac bilgisi doner.
  Future<OnlineMacBilgi?> davetDurum(String kod) async {
    final d = await _c
        .from('davetler')
        .select('seri_id, durum')
        .eq('kod', kod)
        .maybeSingle();
    final sid = d?['seri_id'] as String?;
    if (sid == null) return null;
    return seridenBilgi(sid);
  }

  Future<void> davetIptal() => _c.rpc('davet_iptal');

  // ---------- FAZ 2.4: CÜZDAN GEÇMİŞİ ----------

  /// Kendi defter kayitlarim (RLS: yalniz kendi satirlarim) — son 50.
  Future<List<({String tip, int miktar, String? aciklama, DateTime tarih})>>
      defterGecmisi() async {
    if (!girisYapildi) return [];
    final r = await _c
        .from('defter')
        .select('tip, miktar, aciklama, created_at')
        .eq('user_id', uid!)
        .order('created_at', ascending: false)
        .limit(50);
    return (r as List)
        .map((d) => (
              tip: d['tip'] as String,
              miktar: (d['miktar'] as num).toInt(),
              aciklama: d['aciklama'] as String?,
              tarih: DateTime.parse(d['created_at'] as String),
            ))
        .toList();
  }

  // ---------- FAZ 2.5: ÖDÜLLÜ REKLAM ----------

  /// Odullu reklam izlendikten sonra RIVA tahsil et. Kurallar SUNUCUDA:
  /// odul 50, gunluk tavan 10, ayni islem kimligi iki kez odullenmez.
  Future<int> reklamOdulAl(String islemId) async {
    final r = await _c.rpc('reklam_odul_al',
        params: {'ag_adi': 'admob', 'islem_id': islemId});
    return (r as num).toInt();
  }

  // ---------- FAZ 2.4: LİG KONFİGÜRASYONU ----------

  /// Lig merdiveni (herkese acik): sira, ad, terfi esigi, puan tablosu.
  Future<List<({String kod, String ad, int sira, int terfiEsigi,
      int gBo1, int kBo1, int gBo3, int kBo3})>> ligler() async {
    final r = await _c
        .from('ligler')
        .select('kod, ad, sira, terfi_esigi, g_bo1, k_bo1, g_bo3, k_bo3')
        .order('sira');
    return (r as List)
        .map((l) => (
              kod: l['kod'] as String,
              ad: l['ad'] as String,
              sira: (l['sira'] as num).toInt(),
              terfiEsigi: (l['terfi_esigi'] as num).toInt(),
              gBo1: (l['g_bo1'] as num).toInt(),
              kBo1: (l['k_bo1'] as num).toInt(),
              gBo3: (l['g_bo3'] as num).toInt(),
              kBo3: (l['k_bo3'] as num).toInt(),
            ))
        .toList();
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
