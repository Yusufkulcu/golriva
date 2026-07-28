import 'package:flutter/material.dart';
import 'data/repos.dart';
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

/// Tum veri setlerini paralel yukler (9 JSON, ~5 MB).
class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  GolrivaRepos? repos;
  Object? hata;

  @override
  void initState() {
    super.initState();
    GolrivaRepos.load().then((r) {
      if (mounted) setState(() => repos = r);
    }, onError: (e) {
      if (mounted) setState(() => hata = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (hata != null) {
      return Scaffold(body: Center(child: Text('Veri yüklenemedi: $hata')));
    }
    if (repos == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: GolrivaColors.gold)),
      );
    }
    return LobbyScreen(repos: repos!);
  }
}
