import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      required this.mod});

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
          _onRakipHamle?.call(Map<String, dynamic>.from(h['icerik'] as Map));
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
