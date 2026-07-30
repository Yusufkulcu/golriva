import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golriva/online/supabase_ayar.dart';
import 'package:golriva/screens/lobby.dart';
import 'test_repos.dart';

/// FAZ 2 cevrimdisi guvenlik testleri: Supabase yapilandirilmamis derlemede
/// (testler ve CI dahil) uygulama AGA CIKMAZ ve online arayuz gorunmez.
void main() {
  test('dart-define verilmeden Supabase yapilandirilmamis sayilir', () {
    expect(SupabaseAyar.yapilandirildi, isFalse);
  });

  testWidgets('cevrimdisi derlemede lobide online serit YOK', (tester) async {
    final repos = testRepos();
    await tester.pumpWidget(MaterialApp(home: LobbyScreen(repos: repos)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('RANKED'), findsNothing);
    expect(find.textContaining('hesap aç'), findsNothing);
    expect(find.textContaining('+500'), findsNothing);
    // 10 oyun hala yerli yerinde
    expect(find.text('EN KISA KADRO'), findsOneWidget);
  });
}
