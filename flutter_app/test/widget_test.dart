import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/main.dart';

void main() {
  testWidgets('App renders without smoke errors', (WidgetTester tester) async {
    await tester.pumpWidget(const DTVSteamsApp());
    await tester.pumpAndSettle();
    expect(find.text('dTV'), findsOneWidget);
  });
}
