import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/main.dart';

void main() {
  testWidgets('Smoke and YouTube 1-by-1 feed verification for HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(autoRefresh: false),
    ));

    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('dTV').evaluate().isNotEmpty) {
        break;
      }
    }

    // 1. Verify brand logos and header
    expect(find.text('dTV'), findsWidgets);
    expect(find.text('STEAMS'), findsOneWidget);

    // 2. Verify Downloads folder button in header
    expect(find.text('下載庫'), findsOneWidget);

    // 3. Verify search bar input
    expect(find.byType(TextField), findsOneWidget);

    // 4. Verify Category Filter Pills are removed
    expect(find.text('全部 (All)'), findsNothing);
    expect(find.text('🔥 熱門 (Trending)'), findsNothing);

    // 5. Verify YouTube 1-by-1 style Episode Cards & Part selectors exist
    expect(find.text('最新劇集與節目 (Episodes)'), findsOneWidget);
    expect(find.text('Part 1'), findsWidgets);
    expect(find.text('Part 2'), findsWidgets);

    // 6. Test search filter
    await tester.enterText(find.byType(TextField), '台北');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('最新劇集與節目 (Episodes)'), findsOneWidget);
  });
}
