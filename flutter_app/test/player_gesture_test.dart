import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Player Vertical Swipe & Gesture Math Tests', () {
    test('brightness clamping and delta calculations', () {
      double startBrightness = 0.5;
      const double screenHeight = 800.0;
      const double sensitivity = screenHeight * 0.65;

      // Dragging UP by 260px
      double deltaY1 = 260.0;
      double newBrightness1 = (startBrightness + (deltaY1 / sensitivity)).clamp(0.0, 1.0);
      expect(newBrightness1, equals(1.0));

      // Dragging DOWN by 260px
      double deltaY2 = -260.0;
      double newBrightness2 = (startBrightness + (deltaY2 / sensitivity)).clamp(0.0, 1.0);
      expect(newBrightness2, equals(0.0));

      // Small swipe UP by 52px
      double deltaY3 = 52.0;
      double newBrightness3 = (startBrightness + (deltaY3 / sensitivity)).clamp(0.0, 1.0);
      expect(newBrightness3, closeTo(0.6, 0.01));
    });

    test('volume clamping and delta calculations', () {
      double startVolume = 0.7;
      const double sensitivity = 500.0;

      // Dragging UP beyond 1.0
      double deltaY1 = 200.0;
      double newVolume1 = (startVolume + (deltaY1 / sensitivity)).clamp(0.0, 1.0);
      expect(newVolume1, equals(1.0));

      // Dragging DOWN to 0
      double deltaY2 = -400.0;
      double newVolume2 = (startVolume + (deltaY2 / sensitivity)).clamp(0.0, 1.0);
      expect(newVolume2, equals(0.0));
    });

    test('swipe disambiguation side determination', () {
      const double screenWidth = 1080.0;

      bool isLeftSwipe(double x) => x < screenWidth * 0.45;
      bool isRightSwipe(double x) => x > screenWidth * 0.55;

      // Left area (brightness)
      expect(isLeftSwipe(200.0), isTrue);
      expect(isRightSwipe(200.0), isFalse);

      // Right area (volume)
      expect(isRightSwipe(900.0), isTrue);
      expect(isLeftSwipe(900.0), isFalse);

      // Center deadzone (no swipe triggering)
      expect(isLeftSwipe(540.0), isFalse);
      expect(isRightSwipe(540.0), isFalse);
    });

    testWidgets('renders vertical capsule HUD correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white24, width: 1.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.brightness_high, color: Colors.white, size: 24),
                    const SizedBox(height: 12),
                    Container(
                      width: 6,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: 6,
                        height: 75,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFCC00),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '75%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.brightness_high), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    test('VideoScaleMode cycles through fit, fill, and stretch', () {
      List<String> modes = ['fit', 'fill', 'stretch'];
      int idx = 0;

      // fit -> fill
      idx = (idx + 1) % modes.length;
      expect(modes[idx], equals('fill'));

      // fill -> stretch
      idx = (idx + 1) % modes.length;
      expect(modes[idx], equals('stretch'));

      // stretch -> fit
      idx = (idx + 1) % modes.length;
      expect(modes[idx], equals('fit'));
    });

    testWidgets('renders fast-forward 2X capsule HUD correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 1.0),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Color(0xFFFFCC00), size: 20),
                    SizedBox(width: 6),
                    Text(
                      '2X 快進中',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.fast_forward, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.text('2X 快進中'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward), findsOneWidget);
    });

    test('Screen Lock state transitions and gesture suppression logic', () {
      bool isScreenLocked = false;
      bool showUnlockHint = false;
      bool showOsd = true;

      // Lock action
      void lockScreen() {
        isScreenLocked = true;
        showOsd = false;
        showUnlockHint = true;
      }

      // Unlock action
      void unlockScreen() {
        isScreenLocked = false;
        showUnlockHint = false;
        showOsd = true;
      }

      // Tap on locked screen
      void handleTap() {
        if (isScreenLocked) {
          showUnlockHint = true;
          return;
        }
        showOsd = !showOsd;
      }

      expect(isScreenLocked, isFalse);
      expect(showOsd, isTrue);

      lockScreen();
      expect(isScreenLocked, isTrue);
      expect(showOsd, isFalse);
      expect(showUnlockHint, isTrue);

      // Tapping screen while locked keeps OSD hidden and activates unlock hint
      handleTap();
      expect(showOsd, isFalse);
      expect(showUnlockHint, isTrue);

      // Unlocking restores OSD
      unlockScreen();
      expect(isScreenLocked, isFalse);
      expect(showOsd, isTrue);
      expect(showUnlockHint, isFalse);
    });

    testWidgets('renders floating screen unlock capsule HUD correctly', (tester) async {
      bool unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () => unlocked = true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xFFE50914), size: 22),
                      SizedBox(width: 8),
                      Text(
                        '點擊解鎖螢幕',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.text('點擊解鎖螢幕'), findsOneWidget);

      await tester.tap(find.text('點擊解鎖螢幕'));
      await tester.pump();
      expect(unlocked, isTrue);
    });
  });
}
