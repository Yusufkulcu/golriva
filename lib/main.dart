import 'package:flutter/material.dart';
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

class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  PlayersRepository? repo;
  Object? hata;

  @override
  void initState() {
    super.initState();
    PlayersRepository.load().then(
      (r) => setState(() => repo = r),
      onError: (e) => setState(() => hata = e),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hata != null) {
      return Scaffold(body: Center(child: Text('Veri yüklenemedi: $hata')));
    }
    if (repo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: GolrivaColors.gold)),
      );
    }
    return LobbyScreen(repo: repo!);
  }
}
