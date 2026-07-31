import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SIRA TITRESIMLERI (kullanici istegi): sira degisimini elde hissettir.
/// - Sira BANA gecti → cift guclu vuru (belirgin: "hadi, sira sende!")
/// - Sira RAKIBE gecti → tek hafif vuru ("hamlen gitti")
/// HapticFeedback izin istemez; titresimi kapali cihazlarda sessizce yutulur.
Future<void> siraBanaTitresim() async {
  await HapticFeedback.heavyImpact();
  await Future.delayed(const Duration(milliseconds: 140));
  await HapticFeedback.heavyImpact();
}

Future<void> siraRakibeTitresim() => HapticFeedback.lightImpact();

/// Cevrimici mac kimligi ve DETERMINISTIK kurulum bilgisi.
/// Iki istemci de ayni seed + ayni baslangic zamaniyla ayni motoru kurar —
/// oyun kurulumunu sunucu belirler (maclar.seed), istemciler turetir.
class OnlineMacBilgi {
  final String macId;
  final String seriId;
  final String oyunKodu;
  final int seed;
  final DateTime baslangic; // maclar.created_at — yas hesabi gibi zamana
  // bagli degerler iki istemcide de AYNI olsun diye
  final String p1Uid;
  final String p2Uid;
  final int benimSiram; // 0 = p1 (motor koltugu 0), 1 = p2
  final String rakipAdi;
  final String mod; // bo1 / bo3
  final String masaKod; // caylak/klasik/yuksek/elit ('' = bilinmiyor)
  final bool dostluk; // true: Riva'sız + Elo'suz davet maçı

  OnlineMacBilgi(
      {required this.macId,
      required this.seriId,
      required this.oyunKodu,
      required this.seed,
      required this.baslangic,
      required this.p1Uid,
      required this.p2Uid,
      required this.benimSiram,
      required this.rakipAdi,
      required this.mod,
      this.masaKod = '',
      this.dostluk = false});

  String seatUid(int seat) => seat == 0 ? p1Uid : p2Uid;
}

/// Seri durumu (mac bittikten sonra sorgulanir).
class OnlineSeriDurumu {
  final bool seriBitti;
  final int skor1, skor2;
  final String? kazananUid; // null + bitti = berabere
  final OnlineMacBilgi? sonrakiMac; // bo3'te sıradaki mac
  OnlineSeriDurumu(
      this.seriBitti, this.skor1, this.skor2, this.kazananUid, this.sonrakiMac);
}

/// Hamle senkron kanali. MVP: 1.5 sn'de bir yoklama (sira-tabanli oyunlar
/// icin yeterli; realtime kanala gecis Faz 2.3 optimizasyonu).
/// Hamle icerigi: {"tip":"sec","idx":123} ya da {"tip":"sure"}.
class OnlineMacKanali {
  final OnlineMacBilgi bilgi;
  SupabaseClient get _c => Supabase.instance.client;
  String get _benimUid => bilgi.seatUid(bilgi.benimSiram);

  int _sonHamleId = 0;
  int _hamleNo = 0;
  Timer? _nabiz;
  void Function(Map<String, dynamic>)? _onRakipHamle;
  bool kapandi = false;

  /// bo3'te "SONRAKİ MAÇ" ekranini kuran geri cagri
  /// (oyun_yonlendirici.onlineOyunEkrani baglar — repos kapanisi tasir).
  Widget Function(OnlineMacBilgi bilgi)? sonrakiEkranKur;

  /// Seri sonucu ekranindaki RÖVANŞ butonu icin yeni arama ekranini kuran
  /// geri cagri (ayni masa + ayni mod; repos kapanisi tasir).
  Widget Function()? rovansEkranKur;

  OnlineMacKanali(this.bilgi);

  void Function()? _onMacKapandi;
  int _yoklamaSayisi = 0;

  /// Dinlemeye basla / dinleyicileri degistir. Ayni kanal hazirlik
  /// ekranindan oyun ekranina DEVREDILIR: timer bir kez kurulur,
  /// geri cagrilar her basla() cagrisinda guncellenir.
  void basla(void Function(Map<String, dynamic>) onRakipHamle,
      {void Function()? onMacKapandi}) {
    _onRakipHamle = onRakipHamle;
    _onMacKapandi = onMacKapandi;
    _nabiz ??=
        Timer.periodic(const Duration(milliseconds: 1500), (_) => _yokla());
  }

  Future<void> _yokla() async {
    if (kapandi) return;
    try {
      final r = await _c
          .from('hamleler')
          .select('id, user_id, icerik')
          .eq('mac_id', bilgi.macId)
          .gt('id', _sonHamleId)
          .order('id', ascending: true);
      for (final h in (r as List)) {
        _sonHamleId = (h['id'] as num).toInt();
        if (h['user_id'] != _benimUid) {
          final icerik = Map<String, dynamic>.from(h['icerik'] as Map);
          // rakibin OYUN hamlesi geldi = sira bana gecti → belirgin titresim
          // (hazir/cekildi gibi sinyaller sira degistirmez, titretmez)
          if (icerik['tip'] == 'sec' || icerik['tip'] == 'sure') {
            siraBanaTitresim();
          }
          _onRakipHamle?.call(icerik);
        }
      }
      // EMNIYET AGI: rakip cekildi/mac sunucuda kapandiysa (sinyal kacsa
      // bile) her 4. yoklamada mac durumunu kontrol et.
      if (++_yoklamaSayisi % 4 == 0 && _onMacKapandi != null && !kapandi) {
        final m = await _c
            .from('maclar')
            .select('durum')
            .eq('id', bilgi.macId)
            .maybeSingle();
        if (m != null && m['durum'] == 'bitti') _onMacKapandi!.call();
      }
    } catch (_) {
      // gecici ag hatasi: sonraki yoklamada telafi edilir
    }
  }

  /// Kendi hamlemi gonder (motor zaten yerelde uyguladi).
  Future<void> gonder(Map<String, dynamic> icerik) async {
    // benim OYUN hamlem = sira rakibe gecti → hafif titresim
    if (icerik['tip'] == 'sec' || icerik['tip'] == 'sure') {
      siraRakibeTitresim();
    }
    _hamleNo++;
    try {
      await _c.rpc('hamle_gonder',
          params: {'mid': bilgi.macId, 'no': _hamleNo, 'icerik_j': icerik});
    } catch (_) {
      // tek deneme daha (ayni no — unique kisit cift islemeyi engeller)
      try {
        await _c.rpc('hamle_gonder',
            params: {'mid': bilgi.macId, 'no': _hamleNo, 'icerik_j': icerik});
      } catch (_) {}
    }
  }

  /// Mac sonucunu bildir (kazananSeat: 0/1, null = berabere) ve seri
  /// durumunu getir. IKI istemci de cagirir; sunucu ilk gecerli raporu
  /// isler, ikincisi zararsizca reddedilir.
  Future<OnlineSeriDurumu> sonucBildir(int? kazananSeat) async {
    try {
      await _c.rpc('mac_bitir', params: {
        'mid': bilgi.macId,
        'kazanan_p': kazananSeat == null ? null : bilgi.seatUid(kazananSeat),
      });
    } catch (_) {
      // rakip bizden once bildirdi — sorun degil
    }
    return seriDurumu();
  }

  /// Cekilme: rakibi kazanan olarak bildir (her zaman serbest).
  Future<OnlineSeriDurumu> cekil() =>
      sonucBildir(bilgi.benimSiram == 0 ? 1 : 0);

  /// SUNUCU-SENKRON GERI SAYIM: iki 'hazir' sinyali de sunucuya dustukten
  /// sonra ortak baslangic ani = max(hazir sunucu_ts) + 4 sn. Bu fonksiyon
  /// o ana kalan sureyi SUNUCU saatiyle hesaplar — iki cihaz da ayni mutlak
  /// ani hedefledigi icin geri sayim es zamanli biter (kullanici kurali).
  /// Iki hazir kaydi henuz gorunmuyorsa null doner (tekrar dene).
  Future<Duration?> hazirGeriSayimKalan() async {
    final t0 = DateTime.now();
    final rows = await _c
        .from('hamleler')
        .select('sunucu_ts, icerik')
        .eq('mac_id', bilgi.macId);
    final hazirTs = <DateTime>[];
    for (final r in (rows as List)) {
      final ic = r['icerik'];
      if (ic is Map && ic['tip'] == 'hazir') {
        hazirTs.add(DateTime.parse(r['sunucu_ts'] as String));
      }
    }
    if (hazirTs.length < 2) return null;
    hazirTs.sort();
    final hedef = hazirTs.last.add(const Duration(seconds: 4));
    final simdiStr = await _c.rpc('sunucu_saati');
    final gidisDonus = DateTime.now().difference(t0);
    final sunucuSimdi = DateTime.parse(simdiStr as String)
        .add(Duration(milliseconds: gidisDonus.inMilliseconds ~/ 2));
    return hedef.difference(sunucuSimdi);
  }

  Future<OnlineSeriDurumu> seriDurumu() async {
    final s = await _c
        .from('seriler')
        .select('durum, skor1, skor2, kazanan, p1, p2, mod')
        .eq('id', bilgi.seriId)
        .single();
    final bitti = s['durum'] != 'oyunda';
    OnlineMacBilgi? sonraki;
    if (!bitti) {
      final m = await _c
          .from('maclar')
          .select('id, oyun_kodu, seed, created_at')
          .eq('seri_id', bilgi.seriId)
          .eq('durum', 'oyunda')
          .order('seri_sira', ascending: false)
          .limit(1)
          .maybeSingle();
      if (m != null && m['id'] != bilgi.macId) {
        sonraki = OnlineMacBilgi(
          macId: m['id'] as String,
          seriId: bilgi.seriId,
          oyunKodu: m['oyun_kodu'] as String,
          seed: (m['seed'] as num).toInt(),
          baslangic: DateTime.parse(m['created_at'] as String),
          p1Uid: bilgi.p1Uid,
          p2Uid: bilgi.p2Uid,
          benimSiram: bilgi.benimSiram,
          rakipAdi: bilgi.rakipAdi,
          mod: bilgi.mod,
          masaKod: bilgi.masaKod,
          dostluk: bilgi.dostluk,
        );
      }
    }
    return OnlineSeriDurumu(bitti, (s['skor1'] as num).toInt(),
        (s['skor2'] as num).toInt(), s['kazanan'] as String?, sonraki);
  }

  void kapat() {
    kapandi = true;
    _nabiz?.cancel();
  }
}
