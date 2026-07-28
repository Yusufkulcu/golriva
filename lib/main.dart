import 'package:flutter/material.dart';
import 'data/genc_repository.dart';
import 'data/hedef_repository.dart';
import 'data/players_repository.dart';
import 'screens/lobby.dart';
import 'theme/golriva_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GolrivaApp());
}

class GolrivaApp extends StatelessWidget {
  const GolrivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GOLRIVA',
      debugShowCheckedModeBanner: false,
      theme: GolrivaTheme.dark(),
      home: const _Loader(),
    );
  }
}

/// Uc veri setini paralel yukler (boy + genc + hedef).
class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  PlayersRepository? repo;
  GencRepository? gencRepo;
  HedefRepository? hedefRepo;
  Object? hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final sonuclar = await Future.wait([
        PlayersRepository.load(),
        GencRepository.load(),
        HedefRepository.load(),
      ]);
      if (!mounted) return;
      setState(() {
        repo = sonuclar[0] as PlayersRepository;
        gencRepo = sonuclar[1] as GencRepository;
        hedefRepo = sonuclar[2] as HedefRepository;
      });
    } catch (e) {
      if (mounted) setState(() => hata = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (hata != null) {
      return Scaffold(body: Center(child: Text('Veri yüklenemedi: $hata')));
    }
    if (repo == null || gencRepo == null || hedefRepo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: GolrivaColors.gold)),
      );
    }
    return LobbyScreen(repo: repo!, gencRepo: gencRepo!, hedefRepo: hedefRepo!);
  }
}
