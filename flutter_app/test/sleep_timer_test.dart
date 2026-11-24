import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/services/sleep_timer_manager.dart';
import 'package:dtvsteams/ui/sleep_timer_sheet.dart';

void main() {
  group('SleepTimerManager Unit Tests', () {
    late SleepTimerManager manager;

    setUp(() {
      manager = SleepTimerManager();
      manager.cancelTimer();
      manager.onExpired = null;
    });

    tearDown(() {
      manager.cancelTimer();
      manager.onExpired = null;
    });

    test('initial state is off and inactive', () {
      expect(manager.mode, equals(SleepTimerMode.off));
      expect(manager.isActive, isFalse);
      expect(manager.remainingSeconds, equals(0));
      expect(manager.badgeText, isEmpty);
      expect(manager.formattedTime, isEmpty);
    });

    test('setTimer sets remaining seconds and badge correctly', () {
      manager.setTimer(SleepTimerMode.min15);
      expect(manager.mode, equals(SleepTimerMode.min15));
      expect(manager.isActive, isTrue);
      expect(manager.remainingSeconds, equals(15 * 60));
      expect(manager.badgeText, equals('15m'));
      expect(manager.formattedTime, equals('15:00'));

      manager.setTimer(SleepTimerMode.endOfPart);
      expect(manager.mode, equals(SleepTimerMode.endOfPart));
      expect(manager.badgeText, equals('分段'));
      expect(manager.formattedTime, contains('分段'));
    });

    test('extend15Minutes adds 900 seconds to active timer', () {
      manager.setTimer(SleepTimerMode.min15);
      final initial = manager.remainingSeconds;
      manager.extend15Minutes();
      expect(manager.remainingSeconds, equals(initial + 15 * 60));
      expect(manager.badgeText, equals('30m'));
    });

    test('cancelTimer resets mode to off', () {
      manager.setTimer(SleepTimerMode.min30);
      expect(manager.isActive, isTrue);

      manager.cancelTimer();
      expect(manager.mode, equals(SleepTimerMode.off));
      expect(manager.isActive, isFalse);
      expect(manager.remainingSeconds, equals(0));
    });

    test('onPartFinished triggers onExpired when mode is endOfPart', () {
      bool expiredCalled = false;
      manager.onExpired = () => expiredCalled = true;

      manager.setTimer(SleepTimerMode.endOfPart);
      manager.onPartFinished(isLastPart: false);

      expect(expiredCalled, isTrue);
      expect(manager.isActive, isFalse);
    });

    test('onPartFinished triggers onExpired for endOfEpisode only when isLastPart is true', () {
      bool expiredCalled = false;
      manager.onExpired = () => expiredCalled = true;

      manager.setTimer(SleepTimerMode.endOfEpisode);
      manager.onPartFinished(isLastPart: false);
      expect(expiredCalled, isFalse);

      manager.onPartFinished(isLastPart: true);
      expect(expiredCalled, isTrue);
      expect(manager.isActive, isFalse);
    });
  });

  group('SleepTimerSheet Widget Tests', () {
    testWidgets('renders all sleep timer options and updates manager on tap', (WidgetTester tester) async {
      final manager = SleepTimerManager();
      manager.cancelTimer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSleepTimerSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify title and options rendered
      expect(find.text('睡眠定時器 (Sleep Timer)'), findsOneWidget);
      expect(find.text('關閉'), findsOneWidget);
      expect(find.text('15 分鐘'), findsOneWidget);
      expect(find.text('30 分鐘'), findsOneWidget);
      expect(find.text('45 分鐘'), findsOneWidget);
      expect(find.text('60 分鐘'), findsOneWidget);
      expect(find.text('播完當前分段停止'), findsOneWidget);
      expect(find.text('播完整集所有分段停止'), findsOneWidget);

      // Tap 30 分鐘
      await tester.tap(find.text('30 分鐘'));
      await tester.pumpAndSettle();

      expect(manager.mode, equals(SleepTimerMode.min30));
      expect(manager.isActive, isTrue);

      manager.cancelTimer();
    });
  });
}
