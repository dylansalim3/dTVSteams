import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dtvsteams/catalog/parser.dart';
import 'package:dtvsteams/main.dart';
import 'package:dtvsteams/services/download_manager.dart';
import 'package:dtvsteams/services/settings_manager.dart';
import 'package:dtvsteams/services/update_manager.dart';
import 'package:dtvsteams/ui/about_update_dialog.dart';
import 'package:dtvsteams/ui/app_themes.dart';
import 'package:dtvsteams/ui/app_tokens.dart';
import 'package:dtvsteams/ui/downloads_screen.dart';
import 'package:dtvsteams/ui/favorites_screen.dart';
import 'package:dtvsteams/ui/history_screen.dart';
import 'package:dtvsteams/ui/share_dialog.dart';
import 'package:dtvsteams/ui/sleep_timer_sheet.dart';
import 'package:dtvsteams/ui/storage_location_sheet.dart';
import 'package:dtvsteams/ui/theme_picker_sheet.dart';

void main() {

  final sampleEpisodes = [
    CatalogEpisode(
      id: 'ep-theme-1',
      title: '【綜藝玩很大】2026-11-15 台北特輯',
      date: '2026-11-15',
      url: 'https://example.com/ep1',
      showId: 'mrplayer',
      showName: '綜藝玩很大',
      overview: 'Test episode 1',
      parts: [
        CatalogPart(label: 'Part 1', url: 'https://example.com/ep1-p1.mp4'),
        CatalogPart(label: 'Part 2', url: 'https://example.com/ep1-p2.mp4'),
      ],
    ),
    CatalogEpisode(
      id: 'ep-theme-2',
      title: '【綜藝玩很大】2025-10-01 宜蘭特輯',
      date: '2025-10-01',
      url: 'https://example.com/ep2',
      showId: 'mrplayer',
      showName: '綜藝玩很大',
      overview: 'Test episode 2',
      parts: [
        CatalogPart(label: 'Part 1', url: 'https://example.com/ep2-p1.mp4'),
      ],
    ),
  ];

  late Directory testTempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    testTempDir = await Directory.systemTemp.createTemp('dtvsteams_theme_smoke_');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async => testTempDir.path);
    const storageChannel = MethodChannel('com.dtvsteams.dtvsteams/storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      if (call.method == 'getPublicStorageLocations') {
        return <String, String>{
          'downloads': '${testTempDir.path}/Downloads/dTVSteams',
          'movies': '${testTempDir.path}/Movies/dTVSteams',
        };
      }
      if (call.method == 'hasStoragePermission') return true;
      return null;
    });
  });

  tearDownAll(() async {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    const storageChannel = MethodChannel('com.dtvsteams.dtvsteams/storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    try {
      if (testTempDir.existsSync()) {
        testTempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() {
    SettingsManager().resetForTesting(
      themeId: AppThemes.defaultThemeId,
    );
  });

  tearDown(() {
    SettingsManager().resetForTesting();
  });

  group('21st.dev Theme Catalog & Contrast Invariants', () {
    test('contains default BoardUI theme plus exact first 20 themes from 21st.dev', () {
      expect(AppThemes.twentyFirstDevThemes.length, 20);
      expect(AppThemes.all.length, 21);

      final ids = AppThemes.all.map((t) => t.id).toSet();
      final names = AppThemes.all.map((t) => t.name).toSet();
      expect(ids.length, 21);
      expect(names.length, 21);
      expect(AppThemes.twentyFirstDevThemes.first.id, 'vercel');
      expect(AppThemes.twentyFirstDevThemes.last.id, 'indigo-mono');
    });

    test('every theme satisfies WCAG AA >= 4.5:1 contrast for selected and unselected text', () {
      for (final palette in AppThemes.all) {
        AppColors.setThemeById(palette.id);

        // Selected text on accent surface (buttons, active chips, active pagination)
        final onAccentRatio = AppThemePalette.contrastRatio(AppColors.onAccent, AppColors.accent);
        expect(
          onAccentRatio,
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} (${palette.id}) onAccent/accent contrast too low: $onAccentRatio',
        );

        // Primary & unselected secondary text across all card/shell surfaces
        for (final surface in [
          AppColors.canvas,
          AppColors.surfaceSecondary,
          AppColors.surfacePrimary,
          AppColors.surfaceRaised,
          AppColors.surfaceSunken,
        ]) {
          final primaryContrast = AppThemePalette.contrastRatio(AppColors.textPrimary, surface);
          expect(
            primaryContrast,
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name} textPrimary contrast too low: $primaryContrast',
          );

          final secondaryContrast = AppThemePalette.contrastRatio(AppColors.textSecondary, surface);
          expect(
            secondaryContrast,
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name} textSecondary contrast too low: $secondaryContrast',
          );
        }

        // Semantic status badges & buttons
        expect(
          AppThemePalette.contrastRatio(AppColors.onSuccess, AppColors.success),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} onSuccess/success contrast too low',
        );
        expect(
          AppThemePalette.contrastRatio(AppColors.onWarning, AppColors.warning),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} onWarning/warning contrast too low',
        );
        expect(
          AppThemePalette.contrastRatio(AppColors.success, AppColors.successSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} success/successSurface contrast too low',
        );
        expect(
          AppThemePalette.contrastRatio(AppColors.warning, AppColors.warningSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${palette.name} warning/warningSurface contrast too low',
        );
      }
    });
  });

  group('Settings Theme Switcher & Multi-View Smoke Tests', () {
    void expectVisibleContrast(
      WidgetTester tester,
      Finder textFinder,
      Color backgroundColor,
      String label, {
      double minRatio = 4.5,
    }) {
      expect(textFinder, findsWidgets, reason: 'Expected text widget for $label');
      final textWidget = tester.widget<Text>(textFinder.first);
      final textColor = textWidget.style?.color ?? DefaultTextStyle.of(tester.element(textFinder.first)).style.color;
      expect(textColor, isNotNull, reason: 'Expected resolved color for $label');
      final ratio = AppThemePalette.contrastRatio(textColor!, backgroundColor);
      expect(
        ratio,
        greaterThanOrEqualTo(minRatio),
        reason: 'Low contrast ($ratio < $minRatio) for $label (fg=$textColor, bg=$backgroundColor)',
      );
    }

    testWidgets('Settings opens 21st.dev theme picker, lists all 20 themes, and persists selection', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final updateManager = UpdateManager();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => AboutUpdateDialog.show(context, updateManager),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('外觀主題 (Theme)'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_theme_picker_tile')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings_theme_picker_tile')));
      await tester.pumpAndSettle();

      expect(find.text('外觀主題選擇'), findsOneWidget);
      expect(find.text('1 款預設 + 20 款 21st.dev 精選主題'), findsOneWidget);

      // Scroll through the ThemePickerSheet and confirm every 21st.dev theme is present
      final listFinder = find.descendant(
        of: find.byKey(const ValueKey('theme_picker_list')),
        matching: find.byType(Scrollable),
      );
      for (final theme in AppThemes.twentyFirstDevThemes) {
        final itemFinder = find.byKey(ValueKey('theme_option_${theme.id}'));
        if (itemFinder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            itemFinder,
            120,
            scrollable: listFinder,
            maxScrolls: 40,
          );
        }
        expect(itemFinder, findsOneWidget);
        expect(find.text(theme.name), findsWidgets);
      }

      // Select Lime Frost (light accent pill -> requires dark onAccent)
      final limeFinder = find.byKey(const ValueKey('theme_option_lime-frost'));
      if (limeFinder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          limeFinder,
          -120,
          scrollable: listFinder,
          maxScrolls: 40,
        );
      }
      await Scrollable.ensureVisible(
        tester.element(limeFinder),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(limeFinder);
      await tester.pumpAndSettle();

      expect(SettingsManager().themeId, 'lime-frost');
      expect(AppColors.activeTheme.id, 'lime-frost');
      expectVisibleContrast(tester, find.text('已選文字'), AppColors.accent, 'ThemePicker 已選文字 (lime-frost)');
      expectVisibleContrast(tester, find.text('未選文字'), AppColors.surfacePrimary, 'ThemePicker 未選文字 (lime-frost)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('all views render cleanly with visible selected & unselected text across representative dark, light & high-luma-accent themes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Representative stress themes:
      // - boardui: crimson dark
      // - vercel: pure black canvas + white accent (dark onAccent)
      // - lime-frost: slate dark + bright lime accent (dark onAccent)
      // - zen-linen: warm light surface + soft linen accent
      // - vintage-paper: paper light surface + warm terracotta accent
      // - ocean-breeze: teal dark theme
      final stressThemes = [
        'boardui',
        'vercel',
        'lime-frost',
        'zen-linen',
        'vintage-paper',
        'ocean-breeze',
      ];

      for (final themeId in stressThemes) {
        SettingsManager().resetForTesting(themeId: themeId);

        // 1. HomeScreen + selected/unselected year FilterChips + Pagination + ChannelPicker
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: AppColors.brightness,
              scaffoldBackgroundColor: AppColors.canvas,
            ),
            home: HomeScreen(
              autoRefresh: false,
              initialEpisodes: sampleEpisodes,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('dTV'), findsOneWidget);
        expectVisibleContrast(tester, find.text('dTV'), AppColors.accent, 'Home dTV badge ($themeId)');

        // Selected chip ('全部') vs Unselected chip ('2025')
        expectVisibleContrast(tester, find.text('全部'), AppColors.accent, 'Selected chip 全部 ($themeId)');
        expectVisibleContrast(tester, find.text('2025'), AppColors.surfaceSecondary, 'Unselected chip 2025 ($themeId)');

        // Scroll down to pagination bar and check selected ('1') vs unselected ('2')
        final scrollable = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.byKey(const Key('page_btn_1')), 300, scrollable: scrollable);
        expectVisibleContrast(tester, find.text('1'), AppColors.accent, 'Selected page 1 ($themeId)');
        expectVisibleContrast(tester, find.text('2'), AppColors.surfaceSecondary, 'Unselected page 2 ($themeId)');

        // Unselected/idle Episode Card Part 1 chip on HomeScreen vs Card surfacePrimary
        expectVisibleContrast(
          tester,
          find.text('Part 1').first,
          AppColors.surfacePrimary,
          'EpisodeCard Part 1 chip ($themeId)',
        );

        // Open Channel Picker Sheet and verify selected & unselected channels
        await tester.scrollUntilVisible(find.text('STEAMS'), -300, scrollable: scrollable);
        await tester.tap(find.text('綜藝玩很大').first);
        await tester.pumpAndSettle();
        expect(find.text('切換節目頻道 (Channels)'), findsOneWidget);
        expectVisibleContrast(tester, find.text('切換節目頻道 (Channels)'), AppColors.surfaceSecondary, 'ChannelPicker title ($themeId)');
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 2. Download Selection Sheet + ShareDialog + SleepTimerSheet + StoragePickerSheet
        showDownloadSelectionSheet(
          tester.element(find.byType(HomeScreen)),
          sampleEpisodes.first,
          DownloadManager(),
        );
        await tester.pumpAndSettle();
        expect(find.text('下載分段管理'), findsOneWidget);
        expectVisibleContrast(
          tester,
          find.text('Part 1').last,
          AppColors.accent,
          'DownloadSheet Part 1 pill ($themeId)',
        );
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => showShareDialog(context, sampleEpisodes.first),
                      child: const Text('Share'),
                    ),
                    ElevatedButton(
                      onPressed: () => showSleepTimerSheet(context),
                      child: const Text('Sleep'),
                    ),
                    ElevatedButton(
                      onPressed: () => StorageLocationHelper.showStoragePickerSheet(context),
                      child: const Text('Storage'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Share'));
        await tester.pumpAndSettle();
        expect(find.text('【綜藝玩很大】2026-11-15 台北特輯'), findsOneWidget);
        expectVisibleContrast(tester, find.text('【綜藝玩很大】2026-11-15 台北特輯'), AppColors.surfaceSecondary, 'ShareDialog title ($themeId)');
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sleep'));
        await tester.pumpAndSettle();
        expect(find.text('睡眠定時器 (Sleep Timer)'), findsOneWidget);
        expectVisibleContrast(tester, find.text('睡眠定時器 (Sleep Timer)'), AppColors.surfaceSecondary, 'SleepTimer title ($themeId)');
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        await tester.runAsync(() => tester.tap(find.text('Storage')));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pumpAndSettle();
        expect(find.text('選擇下載儲存位置'), findsOneWidget);
        expectVisibleContrast(tester, find.text('選擇下載儲存位置'), AppColors.surfaceOverlay, 'StorageSheet title ($themeId)');
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pumpAndSettle();

        // 3. DownloadsScreen (Downloads, Favorites, History tabs)
        await tester.pumpWidget(const MaterialApp(home: DownloadsScreen()));
        await tester.pumpAndSettle();
        expectVisibleContrast(tester, find.text('瀏覽節目清單'), AppColors.accent, 'Downloads empty CTA ($themeId)');
        final nav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
        expect(
          AppThemePalette.contrastRatio(nav.selectedItemColor!, AppColors.surfaceOverlay),
          greaterThanOrEqualTo(3.0),
          reason: 'Downloads BottomNav selectedItemColor readable on $themeId',
        );
        expect(
          AppThemePalette.contrastRatio(nav.unselectedItemColor!, AppColors.surfaceOverlay),
          greaterThanOrEqualTo(4.5),
          reason: 'Downloads BottomNav unselectedItemColor contrast on $themeId',
        );

        await tester.tap(find.text('收藏'));
        await tester.pumpAndSettle();
        expect(find.byType(FavoritesBody), findsOneWidget);
        expectVisibleContrast(tester, find.text('尚未加入任何收藏'), AppColors.canvas, 'Favorites empty title ($themeId)');

        await tester.tap(find.text('觀看紀錄'));
        await tester.pumpAndSettle();
        expect(find.byType(HistoryBody), findsOneWidget);
        expectVisibleContrast(tester, find.text('尚無觀看歷史紀錄'), AppColors.canvas, 'History empty title ($themeId)');

        // 4. Standalone FavoritesScreen & HistoryScreen
        await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
        await tester.pumpAndSettle();
        expectVisibleContrast(tester, find.text('我的收藏 (Favorites)'), AppColors.surfaceSecondary, 'FavoritesScreen header ($themeId)');

        await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
        await tester.pumpAndSettle();
        expectVisibleContrast(tester, find.text('觀看紀錄'), AppColors.surfaceSecondary, 'HistoryScreen header ($themeId)');

        // 5. ThemePickerSheet directly
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ThemePickerSheet(settingsManager: SettingsManager()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final pickerScroll = find.descendant(
          of: find.byKey(const ValueKey('theme_picker_list')),
          matching: find.byType(Scrollable),
        );
        final activeOption = find.byKey(ValueKey('theme_option_$themeId'));
        if (activeOption.evaluate().isEmpty) {
          await tester.scrollUntilVisible(activeOption, 120, scrollable: pickerScroll, maxScrolls: 40);
        }
        await Scrollable.ensureVisible(tester.element(activeOption), alignment: 0.5);
        await tester.pumpAndSettle();
        expectVisibleContrast(tester, find.text('使用中'), AppColors.accent, 'ThemePicker selected badge ($themeId)');
        expectVisibleContrast(tester, find.text('套用').first, AppColors.surfacePrimary, 'ThemePicker unselected badge ($themeId)');

        expect(tester.takeException(), isNull, reason: 'Unexpected error rendering views under theme $themeId');
      }
    });
  });
}
