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
    test('contains default BoardUI theme plus exact first 20 themes from 21st.dev, each with light & dark counterparts', () {
      expect(AppThemes.twentyFirstDevThemes.length, 20);
      expect(AppThemes.twentyFirstDevLightThemes.length, 20);
      expect(AppThemes.all.length, 21);
      expect(AppThemes.allLight.length, 21);
      expect(AppThemes.pairs.length, 21);
      expect(AppThemes.allPalettes.length, 42);

      final ids = AppThemes.all.map((t) => t.id).toSet();
      final names = AppThemes.all.map((t) => t.name).toSet();
      expect(ids.length, 21);
      expect(names.length, 21);
      expect(AppThemes.twentyFirstDevThemes.first.id, 'vercel');
      expect(AppThemes.twentyFirstDevThemes.last.id, 'indigo-mono');

      for (final pair in AppThemes.pairs) {
        expect(pair.light.id, pair.dark.id);
        expect(pair.light.name, pair.dark.name);
        expect(pair.light.brightness, Brightness.light);
        expect(pair.dark.brightness, Brightness.dark);
        expect(AppThemes.byId(pair.id, brightness: Brightness.light).brightness, Brightness.light);
        expect(AppThemes.byId(pair.id, brightness: Brightness.dark).brightness, Brightness.dark);
      }
    });

    test('every theme (both light and dark counterparts) satisfies WCAG AA >= 4.5:1 contrast for selected and unselected text', () {
      for (final palette in AppThemes.allPalettes) {
        AppColors.setThemeById(palette.id, brightness: palette.brightness);

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

        // Foreground accent text/icon contrast across primary surfaces
        for (final surface in [
          AppColors.canvas,
          AppColors.surfaceSecondary,
          AppColors.surfaceRaised,
        ]) {
          final accentFgContrast = AppThemePalette.contrastRatio(AppColors.accentForeground, surface);
          expect(
            accentFgContrast,
            greaterThanOrEqualTo(4.5),
            reason: '${palette.name} (${palette.brightness}) accentForeground contrast too low: $accentFgContrast',
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

      // Switch to Light mode inside ThemePickerSheet and confirm light counterpart is applied
      await tester.tap(find.byKey(const ValueKey('theme_picker_light_mode_button')));
      await tester.pumpAndSettle();
      expect(SettingsManager().themeBrightness, Brightness.light);
      expect(AppColors.brightness, Brightness.light);
      expect(AppColors.activeTheme.id, 'lime-frost');
      expect(AppColors.canvas, AppThemes.byId('lime-frost', brightness: Brightness.light).canvas);
      expectVisibleContrast(tester, find.text('已選文字'), AppColors.accent, 'ThemePicker 已選文字 (lime-frost light)');
      expectVisibleContrast(tester, find.text('未選文字'), AppColors.surfacePrimary, 'ThemePicker 未選文字 (lime-frost light)');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Settings sheet provides light/dark mode switch button that updates current theme counterpart', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SettingsManager().resetForTesting(
        themeId: 'catppuccin',
        themeBrightness: Brightness.dark,
      );

      final updateManager = UpdateManager();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: SettingsManager(),
          builder: (context, _) {
            AppColors.setThemeById(
              SettingsManager().themeId,
              brightness: SettingsManager().themeBrightness,
            );
            return AppThemeScope(
              notifier: SettingsManager(),
              child: MaterialApp(
                theme: ThemeData(brightness: AppColors.brightness),
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
          },
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings_theme_mode_toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_light_mode_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings_dark_mode_button')), findsOneWidget);
      expect(find.text('目前為深色模式'), findsOneWidget);
      expect(AppColors.brightness, Brightness.dark);

      // Switch to Light mode counterpart of Catppuccin
      await tester.tap(find.byKey(const ValueKey('settings_light_mode_button')));
      await tester.pumpAndSettle();

      expect(SettingsManager().themeBrightness, Brightness.light);
      expect(SettingsManager().isDarkMode, isFalse);
      expect(SettingsManager().themeId, 'catppuccin');
      expect(AppColors.brightness, Brightness.light);
      expect(AppColors.canvas, AppThemes.byId('catppuccin', brightness: Brightness.light).canvas);
      expect(find.text('目前為淺色模式'), findsOneWidget);

      // Switch back to Dark mode counterpart of Catppuccin
      await tester.tap(find.byKey(const ValueKey('settings_dark_mode_button')));
      await tester.pumpAndSettle();

      expect(SettingsManager().themeBrightness, Brightness.dark);
      expect(SettingsManager().isDarkMode, isTrue);
      expect(AppColors.brightness, Brightness.dark);
      expect(AppColors.canvas, AppThemes.byId('catppuccin', brightness: Brightness.dark).canvas);
      expect(find.text('目前為深色模式'), findsOneWidget);
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
      final stressConfigs = <(String, Brightness)>[
        ('boardui', Brightness.dark),
        ('boardui', Brightness.light),
        ('vercel', Brightness.dark),
        ('vercel', Brightness.light),
        ('lime-frost', Brightness.dark),
        ('lime-frost', Brightness.light),
        ('zen-linen', Brightness.light),
        ('vintage-paper', Brightness.light),
        ('catppuccin', Brightness.light),
        ('ocean-breeze', Brightness.dark),
      ];

      for (final (themeId, brightness) in stressConfigs) {
        SettingsManager().resetForTesting(themeId: themeId, themeBrightness: brightness);

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

    testWidgets('live theme switch repaints HomeScreen header, episode cards, and pagination without switching TV show', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = SettingsManager();
      await tester.pumpWidget(
        ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            AppColors.setThemeById(settings.themeId, brightness: settings.themeBrightness);
            return AppThemeScope(
              notifier: settings,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: AppColors.brightness,
                  scaffoldBackgroundColor: AppColors.canvas,
                  primaryColor: AppColors.accent,
                ),
                home: HomeScreen(
                  autoRefresh: false,
                  initialEpisodes: sampleEpisodes,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial BoardUI crimson colors on Header Bar, EpisodeCard, and active pagination button
      final headerFinder = find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration && ((w.decoration as BoxDecoration).border as Border?)?.bottom != null && (w.decoration as BoxDecoration).color != null,
      );
      expect((tester.widget<Container>(headerFinder.first).decoration as BoxDecoration).color, AppThemes.boardUiDefault.surfaceSecondary);

      final cardContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(YouTubeEpisodeCard).first,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(AppRadius.card),
          ),
        ).first,
      );
      final initialCardBg = (cardContainer.decoration as BoxDecoration).color;
      expect(initialCardBg, AppThemes.boardUiDefault.surfaceSecondary);

      final initialPage1Box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('page_btn_1')),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color != null,
          ),
        ).first,
      );
      expect((initialPage1Box.decoration as BoxDecoration).color, AppThemes.boardUiDefault.accent);

      // Switch to Vercel dark theme without changing channel/episodes
      await tester.runAsync(() => settings.setThemeId('vercel'));
      await tester.pumpAndSettle();

      final vercelDarkPalette = AppThemes.byId('vercel', brightness: Brightness.dark);
      expect((tester.widget<Container>(headerFinder.first).decoration as BoxDecoration).color, vercelDarkPalette.surfaceSecondary);

      // Switch to Vercel light counterpart without changing themeId or episodes
      await tester.runAsync(() => settings.setThemeBrightness(Brightness.light));
      await tester.pumpAndSettle();

      final lightPalette = AppThemes.byId('vercel', brightness: Brightness.light);
      expect((tester.widget<Container>(headerFinder.first).decoration as BoxDecoration).color, lightPalette.surfaceSecondary);
      final lightCard = tester.widget<Container>(
        find.descendant(
          of: find.byType(YouTubeEpisodeCard).first,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(AppRadius.card),
          ),
        ).first,
      );
      expect((lightCard.decoration as BoxDecoration).color, lightPalette.surfaceSecondary);

      final lightPage1Box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('page_btn_1')),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color != null,
          ),
        ).first,
      );
      expect((lightPage1Box.decoration as BoxDecoration).color, lightPalette.accent);

      final lightTitle = tester.widget<Text>(find.text('最新劇集與節目 (Episodes)'));
      expect(lightTitle.style?.color, lightPalette.textPrimary);

      // Switch to Catppuccin while staying in Light mode -> gets Catppuccin Latte light counterpart
      await tester.runAsync(() => settings.setThemeId('catppuccin'));
      await tester.pumpAndSettle();

      final catppuccinLight = AppThemes.byId('catppuccin', brightness: Brightness.light);
      expect((tester.widget<Container>(headerFinder.first).decoration as BoxDecoration).color, catppuccinLight.surfaceSecondary);
      final catppuccinCard = tester.widget<Container>(
        find.descendant(
          of: find.byType(YouTubeEpisodeCard).first,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).borderRadius == BorderRadius.circular(AppRadius.card),
          ),
        ).first,
      );
      expect((catppuccinCard.decoration as BoxDecoration).color, catppuccinLight.surfaceSecondary);

      final catppuccinPage1Box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('page_btn_1')),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color != null,
          ),
        ).first,
      );
      expect((catppuccinPage1Box.decoration as BoxDecoration).color, catppuccinLight.accent);
      expect(tester.takeException(), isNull);
    });
  });
}
