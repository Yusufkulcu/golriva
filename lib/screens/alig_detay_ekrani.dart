import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/repos.dart';
import '../online/alig_servis.dart';
import '../online/hata_raporu.dart';
import '../online/online_servis.dart';
import '../online/oyun_yonlendirici.dart';
import '../theme/golriva_theme.dart';
import '../widgets/golriva_ui.dart';

/// ARKADAŞ LİGİ DETAY (Faz 2.19) — puan tablosu + fikstür + HAZIRIM akışı.
/// Zorunlu saat yok: fikstürdeki rakipler lig ekranından HAZIRIM işaretler;
/// iki taraf 90 sn penceresinde hazırsa maç (dostluk bo1, rulet) başlar.
class AligDetayEkrani extends StatefulWidget {
  final GolrivaRepos repos;
  final String ligId;
  const AligDetayEkrani(
      {super.key, required this.repos, required this.ligId});

  @override
  State<AligDetayEkrani> createState() => _AligDetayEkraniState();
}

class _AligDetayEkraniState extends State<AligDetayEkrani> {
  final servis = AligServis();
  AligDetay? lig;
  String? hata;
  Timer? _tazele; // genel ekran yenilemesi (8 sn)
  Timer? _hazirNabiz; // HAZIRIM sonrası bekleme yoklaması (4 sn)
  String? bekleyenMacId; // hazır bekleme penceresi açık olan maç
  bool _macaGidiliyor = false;

  String get benimUid => servis.uid ?? '';

  @override
  void initState() {
    super.initState();
    _yukle();
    _tazele = Timer.periodic(const Duration(seconds: 8), (_) => _yukle());
  }

  @override
  void dispose() {
    _tazele?.cancel();
    _hazirNabiz?.cancel();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final r = await servis.ligDetay(widget.ligId);
      if (mounted) {
        setState(() {
          lig = r;
          hata = null;
        });
      }
    } catch (e, s) {
      if (mounted && lig == null) {
        setState(() => hata = temizMesaj('alig.detay', e,
            'Lig yüklenemedi — tekrar dene.', s));
      }
    }
  }

  // ---------- HAZIRIM AKIŞI ----------
  Future<void> _hazirim(AligMac mc) async {
    // İLK çağrı hataları KULLANICIYA gösterir (örn. "önce devam eden
    // lig maçını bitir" — faz 2.22 tek maç kuralı).
    try {
      final d = await servis.ligHazir(mc.id);
      if (!mounted) return;
      if (d.durum == 'oyunda' && d.seriId != null) {
        await _macaGir(d.seriId!);
        return;
      }
      setState(() => bekleyenMacId = mc.id);
    } catch (e, s) {
      if (mounted) {
        final m = '$e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(m.contains('devam eden')
                ? 'Önce devam eden lig maçını bitir — fikstürdeki '
                    'MAÇA DÖN butonunu kullan.'
                : temizMesaj('alig.hazir', e,
                    'Hazır sinyali gönderilemedi — tekrar dene.', s))));
      }
      return;
    }
    _hazirNabiz?.cancel();
    _hazirNabiz = Timer.periodic(
        const Duration(seconds: 4), (_) => _hazirYokla(mc.id));
  }

  Future<void> _hazirYokla(String macId) async {
    if (!mounted || bekleyenMacId != macId || _macaGidiliyor) return;
    try {
      final d = await servis.ligHazir(macId);
      if (!mounted || bekleyenMacId != macId) return;
      if (d.durum == 'oyunda' && d.seriId != null) {
        await _macaGir(d.seriId!);
      } else if (d.durum == 'bitti') {
        _beklemeyiKapat();
        _yukle();
      }
    } catch (e, s) {
      hataBildir('alig.hazir', e, s);
    }
  }

  void _beklemeyiKapat() {
    _hazirNabiz?.cancel();
    if (mounted) setState(() => bekleyenMacId = null);
  }

  Future<void> _macaGir(String seriId) async {
    if (_macaGidiliyor) return;
    _macaGidiliyor = true;
    _hazirNabiz?.cancel();
    try {
      final bilgi = await OnlineServis().seridenBilgi(seriId);
      if (bilgi == null || !mounted) return;
      setState(() => bekleyenMacId = null);
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => onlineOyunEkrani(widget.repos, bilgi)));
    } catch (e, s) {
      hataBildir('alig.macaGir', e, s);
    } finally {
      _macaGidiliyor = false;
      if (mounted) _yukle();
    }
  }

  // Devam eden maçı (uygulama kapanmış vs.) kaldığı yerden aç.
  Future<void> _devamEt(AligMac mc) async {
    if (mc.seriId != null) await _macaGir(mc.seriId!);
  }

  Future<void> _ayril() async {
    final l = lig;
    if (l == null) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        title: Text('Ligden ayrıl?',
            style: GoogleFonts.bigShouldersDisplay(
                fontWeight: FontWeight.w900, color: GolrivaColors.ink)),
        content: Text(
            l.durum == 'acik'
                ? (l.kurucu == benimUid
                    ? 'Kurucu olarak ayrılırsan lig İPTAL edilir ve herkese '
                        'katılım ücreti iade edilir.'
                    : 'Lig başlamadığı için katılım ücretin iade edilir.')
                : 'Lig sürerken ayrılırsan kalan maçların rakiplerine '
                    'HÜKMEN yazılır ve katılım ücretin İADE EDİLMEZ.',
            style: GoogleFonts.figtree(color: GolrivaColors.dim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('VAZGEÇ')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('AYRIL',
                  style: TextStyle(color: GolrivaColors.bad))),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await servis.ligAyril(l.id);
      if (mounted) Navigator.pop(context);
    } catch (e, s) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(temizMesaj('alig.ayril', e,
                'Ayrılma işlemi yapılamadı.', s))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = lig;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(children: [
          Text(l?.ad.toUpperCase() ?? 'ARKADAŞ LİGİ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.bigShouldersDisplay(
                  fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.5)),
          if (l != null)
            Text(
                switch (l.durum) {
                  'acik' => '${l.uyeler.length}/${l.boyut} OYUNCU BEKLENİYOR',
                  'aktif' => 'HAVUZ ${l.havuz} · ${_kalanYazi(l.bitisAt)}',
                  'bitti' => 'LİG BİTTİ',
                  _ => 'İPTAL EDİLDİ',
                },
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 9.5,
                    color: GolrivaColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
        ]),
        centerTitle: true,
        actions: [
          if (l != null && (l.durum == 'acik' || l.durum == 'aktif'))
            IconButton(
                tooltip: 'Ligden ayrıl',
                icon: const Icon(Icons.logout,
                    color: GolrivaColors.dim, size: 20),
                onPressed: _ayril),
        ],
      ),
      body: SafeArea(
        child: hata != null
            ? Center(
                child: Text(hata!,
                    style: GoogleFonts.figtree(color: GolrivaColors.bad)))
            : l == null
                ? const Center(
                    child: CircularProgressIndicator(
                        color: GolrivaColors.gold, strokeWidth: 2.5))
                : RefreshIndicator(
                    color: GolrivaColors.gold,
                    onRefresh: _yukle,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        if (l.durum == 'acik') _kodKarti(l),
                        if (l.durum == 'bitti') _sampiyonKarti(l),
                        _puanTablosu(l),
                        const SizedBox(height: 12),
                        if (l.durum != 'acik') _fikstur(l),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _kalanYazi(DateTime? bitis) {
    if (bitis == null) return '';
    final kalan = bitis.difference(DateTime.now());
    if (kalan.isNegative) return 'SÜRE DOLDU';
    if (kalan.inDays >= 1) return '${kalan.inDays} GÜN KALDI';
    return '${kalan.inHours} SAAT KALDI';
  }

  Widget _kodKarti(AligDetay l) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: gKartDekor(),
        child: Column(children: [
          Text('ARKADAŞLARINA KODU GÖNDER — LİG DOLUNCA BAŞLAR',
              textAlign: TextAlign.center,
              style: GoogleFonts.figtree(
                  fontSize: 9.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.dim)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: l.kod));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kod kopyalandı')));
            },
            child: Text(l.kod,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: GolrivaColors.goldHi)),
          ),
          const SizedBox(height: 4),
          Text(
              l.giris == 0
                  ? 'Ücretsiz lig — ödül havuzu yok, şampiyonluk onuru var.'
                  : 'Katılım ${l.giris} Riva · şampiyona havuzun %80\'i.',
              style: GoogleFonts.figtree(
                  fontSize: 10.5, color: GolrivaColors.dim)),
        ]),
      );

  Widget _sampiyonKarti(AligDetay l) {
    final adlar = l.kazanan != null
        ? l.uyeAdi(l.kazanan!)
        : l.kazananlar.map(l.uyeAdi).join(' & ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: gKartDekor(),
      child: Column(children: [
        Text(l.kazananlar.length > 1 ? 'ŞAMPİYONLAR (PAYLAŞIM)' : 'ŞAMPİYON',
            style: GoogleFonts.figtree(
                fontSize: 10,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w700,
                color: GolrivaColors.dim)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(adlar.toUpperCase(),
              style: GoogleFonts.bigShouldersDisplay(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: GolrivaColors.goldHi,
                  letterSpacing: 1)),
        ),
        if (l.havuz > 0)
          Text('Ödül: ${(l.havuz * 0.8).floor()} Riva',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.gold)),
      ]),
    );
  }

  // ---------- PUAN TABLOSU ----------
  Widget _puanTablosu(AligDetay l) => Container(
        padding: const EdgeInsets.all(12),
        decoration: kartDekor(r: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          etiket('PUAN TABLOSU · G3 B1 M0'),
          const SizedBox(height: 6),
          Row(children: [
            const SizedBox(width: 22),
            Expanded(
                child: Text('OYUNCU',
                    style: GoogleFonts.figtree(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: GolrivaColors.dim2))),
            for (final b in ['O', 'G', 'B', 'M', 'P'])
              SizedBox(
                  width: 26,
                  child: Text(b,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.figtree(
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                          color: GolrivaColors.dim2))),
          ]),
          const Divider(color: GolrivaColors.edge2, height: 12),
          for (final (i, u) in l.uyeler.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(children: [
                SizedBox(
                    width: 22,
                    child: Text('${i + 1}.',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 11, color: GolrivaColors.dim))),
                Expanded(
                  child: Text(
                      u.aktif ? u.ad : '${u.ad} (ayrıldı)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.figtree(
                          fontSize: 12.5,
                          fontWeight: u.userId == benimUid
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: !u.aktif
                              ? GolrivaColors.dim2
                              : u.userId == benimUid
                                  ? GolrivaColors.goldHi
                                  : GolrivaColors.ink)),
                ),
                for (final v in [u.oynanan, u.g, u.b, u.m])
                  SizedBox(
                      width: 26,
                      child: Text('$v',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, color: GolrivaColors.dim))),
                SizedBox(
                    width: 26,
                    child: Text('${u.puan}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: GolrivaColors.goldHi))),
              ]),
            ),
        ]),
      );

  // ---------- FİKSTÜR ----------
  Widget _fikstur(AligDetay l) {
    final haftalar = <int, List<AligMac>>{};
    for (final m in l.maclar) {
      haftalar.putIfAbsent(m.tur, () => []).add(m);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      etiket('FİKSTÜR — MAÇLARI İSTEDİĞİN ZAMAN OYNA'),
      const SizedBox(height: 2),
      Text(
          'Rakibinle lig ekranına gelin, ikiniz de HAZIRIM deyin — maç başlar. '
          'Oyunu rulet seçer; Riva ve Elo işlemez, sadece lig puanı.',
          style: GoogleFonts.figtree(fontSize: 10, color: GolrivaColors.dim2)),
      const SizedBox(height: 8),
      for (final hafta in haftalar.keys.toList()..sort()) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text('$hafta. HAFTA',
              style: GoogleFonts.figtree(
                  fontSize: 9.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: GolrivaColors.gold)),
        ),
        for (final m in haftalar[hafta]!) _macKart(l, m),
      ],
    ]);
  }

  Widget _macKart(AligDetay l, AligMac m) {
    final benimki = m.oyuncusu(benimUid);
    final bekliyorum = bekleyenMacId == m.id;
    final simdi = DateTime.now();
    final rakipHazir = benimki && m.durum == 'bekliyor' &&
        m.rakipHazir(benimUid, simdi.toUtc());
    // Faz 2.22: devam eden maçım varken başka maça HAZIRIM denemez.
    final benimOyunda = l.maclar.any(
        (x) => x.durum == 'oyunda' && x.oyuncusu(benimUid));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: kartDekor(r: 14).copyWith(
          border: Border.all(
              color: benimki && m.durum == 'bekliyor'
                  ? GolrivaColors.goldDeep
                  : GolrivaColors.edge2)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(
                '${l.uyeAdi(m.p1)}  —  ${l.uyeAdi(m.p2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.figtree(
                    fontSize: 12.5,
                    fontWeight:
                        benimki ? FontWeight.w800 : FontWeight.w500,
                    color: benimki
                        ? GolrivaColors.ink
                        : GolrivaColors.dim)),
          ),
          _macDurum(l, m),
        ]),
        if (benimki && m.durum == 'bekliyor' && l.durum == 'aktif' &&
            benimOyunda) ...[
          const SizedBox(height: 6),
          Text('Önce devam eden maçını bitir — sonra buna hazır olabilirsin.',
              style: GoogleFonts.figtree(
                  fontSize: 10.5, color: GolrivaColors.dim2)),
        ] else if (benimki && m.durum == 'bekliyor' && l.durum == 'aktif') ...[
          const SizedBox(height: 8),
          if (bekliyorum)
            Row(children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: GolrivaColors.gold, strokeWidth: 2)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Rakip bekleniyor… (o da HAZIRIM demeli)',
                    style: GoogleFonts.figtree(
                        fontSize: 11, color: GolrivaColors.dim)),
              ),
              TextButton(
                  onPressed: _beklemeyiKapat,
                  child: const Text('VAZGEÇ',
                      style: TextStyle(fontSize: 11))),
            ])
          else
            Row(children: [
              if (rakipHazir) ...[
                const Icon(Icons.circle, size: 9, color: GolrivaColors.ok),
                const SizedBox(width: 5),
                Expanded(
                  child: Text('Rakip HAZIR — dokun, maç başlasın!',
                      style: GoogleFonts.figtree(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: GolrivaColors.ok)),
                ),
              ] else
                const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: GolrivaColors.gold,
                    foregroundColor: const Color(0xFF231A04),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8)),
                onPressed: () => _hazirim(m),
                child: Text('HAZIRIM',
                    style: GoogleFonts.bigShouldersDisplay(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 14)),
              ),
            ]),
        ],
        if (benimki && m.durum == 'oyunda') ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: GolrivaColors.goldHi,
                  side: const BorderSide(color: GolrivaColors.goldDeep),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8)),
              onPressed: () => _devamEt(m),
              child: Text('MAÇA DÖN',
                  style: GoogleFonts.bigShouldersDisplay(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontSize: 13)),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _macDurum(AligDetay l, AligMac m) {
    if (m.durum == 'oyunda') {
      return Text('OYNANIYOR',
          style: GoogleFonts.figtree(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: GolrivaColors.ok));
    }
    if (m.durum == 'bitti') {
      final yazi = m.katilimsiz
          ? 'İPTAL'
          : m.kazanan == null
              ? 'BERABERE'
              : '${l.uyeAdi(m.kazanan!)}${m.hukmen ? " (hükmen)" : ""}';
      return Text(yazi,
          style: GoogleFonts.figtree(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: m.katilimsiz
                  ? GolrivaColors.dim2
                  : m.kazanan == null
                      ? GolrivaColors.dim
                      : GolrivaColors.goldHi));
    }
    return Text('BEKLİYOR',
        style: GoogleFonts.figtree(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: GolrivaColors.dim2));
  }
}
