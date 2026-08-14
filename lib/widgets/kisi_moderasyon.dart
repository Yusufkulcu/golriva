import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../online/hata_raporu.dart';
import '../online/online_servis.dart';
import '../theme/golriva_theme.dart';
import 'golriva_ui.dart';

/// FAZ 2.24 — ŞİKAYET + ENGELLEME (Apple 1.2 uyumu).
/// Rakip/arkadaş adının göründüğü her yerden çağrılabilen ortak alt sayfa:
/// Şikayet Et (sebep + isteğe bağlı açıklama) ve Engelle.
/// [engellendiyse] engelleme başarıyla tamamlanınca çağrılır
/// (liste tazeleme vb. için).

const _sebepler = <(String, String)>[
  ('uygunsuz_ad', 'Uygunsuz kullanıcı adı'),
  ('hakaret', 'Hakaret / taciz'),
  ('hile', 'Hile şüphesi'),
  ('spam', 'Spam / rahatsız etme'),
  ('diger', 'Diğer'),
];

void kisiModerasyonAc(BuildContext context, String ad,
    {VoidCallback? engellendiyse}) {
  final servis = OnlineServis();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: GolrivaColors.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            avatar(ad, 34, kenar: GolrivaColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(ad,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.figtree(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 12),
          _secenek(sctx, 'alev', 'Şikayet et',
              'Uygunsuz ad, hakaret, hile ya da spam bildir', () {
            Navigator.pop(sctx);
            _sikayetDialog(context, servis, ad);
          }),
          const SizedBox(height: 8),
          _secenek(
              sctx,
              'kilit',
              'Engelle',
              'Seninle maç kuramaz, davet ve istek gönderemez',
              () => _engelleOnay(sctx, context, servis, ad, engellendiyse),
              tehlike: true),
        ]),
      ),
    ),
  );
}

Widget _secenek(BuildContext ctx, String ikon, String baslik, String alt,
        VoidCallback onTap,
        {bool tehlike = false}) =>
    InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: kartDekor(r: 16),
        child: Row(children: [
          gIkon(ikon, 16,
              tehlike ? GolrivaColors.bad : GolrivaColors.goldHi),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik,
                      style: GoogleFonts.figtree(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: tehlike
                              ? GolrivaColors.bad
                              : GolrivaColors.ink)),
                  Text(alt,
                      style: GoogleFonts.figtree(
                          fontSize: 11, color: GolrivaColors.dim)),
                ]),
          ),
        ]),
      ),
    );

void _engelleOnay(BuildContext sctx, BuildContext dis, OnlineServis servis,
    String ad, VoidCallback? engellendiyse) {
  Navigator.pop(sctx);
  showDialog<void>(
    context: dis,
    builder: (dctx) => AlertDialog(
      backgroundColor: GolrivaColors.card,
      title: Text('$ad engellensin mi?',
          style: GoogleFonts.figtree(
              fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text(
          'Engellediğin kullanıcı seninle maç kuramaz, arkadaşlık isteği ve '
          'davet gönderemez; varsa arkadaşlığınız kaldırılır. '
          'Engeli daha sonra Arkadaşlar ekranından kaldırabilirsin.',
          style: GoogleFonts.figtree(
              fontSize: 12.5, color: GolrivaColors.dim, height: 1.5)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('VAZGEÇ',
                style: TextStyle(color: GolrivaColors.dim))),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: GolrivaColors.bad,
              foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.pop(dctx);
            try {
              await servis.kisiEngelle(ad);
              engellendiyse?.call();
              if (dis.mounted) {
                ScaffoldMessenger.of(dis).showSnackBar(
                    SnackBar(content: Text('$ad engellendi')));
              }
            } catch (e, s) {
              if (dis.mounted) {
                ScaffoldMessenger.of(dis).showSnackBar(SnackBar(
                    content: Text(temizMesaj('moderasyon.engelle', e,
                        'Şu an engellenemedi — tekrar dene.', s))));
              }
            }
          },
          child: const Text('ENGELLE'),
        ),
      ],
    ),
  );
}

void _sikayetDialog(BuildContext dis, OnlineServis servis, String ad) {
  var sebep = _sebepler.first.$1;
  final detay = TextEditingController();
  showDialog<void>(
    context: dis,
    builder: (dctx) => StatefulBuilder(
      builder: (dctx, setD) => AlertDialog(
        backgroundColor: GolrivaColors.card,
        title: Text('$ad kullanıcısını bildir',
            style: GoogleFonts.figtree(
                fontSize: 16, fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (kod, etiketS) in _sebepler)
              RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: GolrivaColors.gold,
                value: kod,
                groupValue: sebep,
                onChanged: (v) => setD(() => sebep = v ?? sebep),
                title: Text(etiketS,
                    style: GoogleFonts.figtree(fontSize: 13)),
              ),
            TextField(
              controller: detay,
              maxLines: 3,
              maxLength: 300,
              style: GoogleFonts.figtree(
                  fontSize: 13, color: GolrivaColors.ink),
              decoration: const InputDecoration(
                  hintText: 'Açıklama (isteğe bağlı)…',
                  hintStyle: TextStyle(color: GolrivaColors.dim2)),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('VAZGEÇ',
                  style: TextStyle(color: GolrivaColors.dim))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: GolrivaColors.gold,
                foregroundColor: const Color(0xFF231A04)),
            onPressed: () async {
              Navigator.pop(dctx);
              try {
                await servis.sikayetGonder(ad, sebep, detay.text);
                if (dis.mounted) {
                  ScaffoldMessenger.of(dis).showSnackBar(const SnackBar(
                      content: Text(
                          'Bildirimin alındı — ekibimiz inceleyecek. '
                          'Teşekkürler!')));
                }
              } catch (e, s) {
                final m = '$e';
                if (dis.mounted) {
                  ScaffoldMessenger.of(dis).showSnackBar(SnackBar(
                      content: Text(m.contains('zaten bildirdin')
                          ? 'Bu kullanıcıyı zaten bildirdin — ekip inceleyecek.'
                          : m.contains('sınır')
                              ? 'Günlük şikayet sınırına ulaştın.'
                              : temizMesaj('moderasyon.sikayet', e,
                                  'Şu an gönderilemedi — tekrar dene.', s))));
                }
              }
            },
            child: const Text('GÖNDER'),
          ),
        ],
      ),
    ),
  );
}
