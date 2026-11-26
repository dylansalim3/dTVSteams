import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_themes.dart';

/// Primitive palette values aligned with BoardUI's Tailwind v4 neutral/red scale.
abstract final class AppPrimitives {
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral850 = Color(0xFF1E1E1E);
  static const Color neutral900 = Color(0xFF171717);
  static const Color neutral925 = Color(0xFF121212);
  static const Color neutral950 = Color(0xFF0A0A0A);

  static const Color gray950 = neutral950;
  static const Color gray900 = neutral925;
  static const Color gray850 = neutral900;
  static const Color gray800 = neutral850;
  static const Color gray750 = neutral800;
  static const Color gray700 = Color(0xFF2F2F2F);
  static const Color gray600 = neutral700;

  static const Color red400 = Color(0xFFF87171);
  static const Color red500 = Color(0xFFE50914);
  static const Color red600 = Color(0xFFB80710);
  static const Color green500 = Color(0xFF46D369);
}

/// Inherited scope that notifies any dependent widget whenever [SettingsManager]
/// changes theme so even `const` subtrees and pushed routes repaint immediately.
class AppThemeScope extends InheritedNotifier<Listenable> {
  const AppThemeScope({
    super.key,
    required Listenable notifier,
    required super.child,
  }) : super(notifier: notifier);
}

/// Semantic color roles dynamically backed by the active [AppThemePalette].
abstract final class AppColors {
  static AppThemePalette _active = AppThemes.boardUiDefault;

  static AppThemePalette get activeTheme => _active;
  static void setThemeById(String? id) {
    _active = AppThemes.byId(id);
  }

  /// Registers a build dependency on [AppThemeScope] (and [Theme.of]) so
  /// any widget reading `AppColors.*` rebuilds synchronously on theme change.
  static AppThemePalette watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    Theme.of(context);
    return _active;
  }

  static Brightness get brightness => _active.brightness;
  static Color get canvas => _active.canvas;
  static Color get surfaceSecondary => _active.surfaceSecondary;
  static Color get surfacePrimary => _active.surfacePrimary;
  static Color get surfaceRaised => _active.surfaceRaised;
  static Color get surfaceOverlay => _active.surfaceSecondary;
  static Color get surfaceInteractive => _active.surfacePrimary;
  static Color get surfaceSunken => _active.surfaceSunken;
  static Color get cardBg => _active.surfaceRaised;

  static Color get accent => _active.accent;
  static Color get onAccent => _active.onAccent;
  static Color get accentHover => _active.accentHover;
  static Color get accentSoft => _active.accentSoft;

  static Color get success => _active.brightness == Brightness.light
      ? const Color(0xFF15803D)
      : AppPrimitives.green500;
  static Color get onSuccess => _active.brightness == Brightness.light
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF08220E);
  static Color get successSurface => _active.brightness == Brightness.light
      ? const Color(0xFFDCFCE7)
      : const Color(0xFF132E19);
  static Color get successMutedSurface => _active.brightness == Brightness.light
      ? const Color(0xFFECFDF5)
      : const Color(0xFF19241B);
  static Color get dangerSurface => _active.brightness == Brightness.light
      ? const Color(0xFFFEE2E2)
      : const Color(0xFF2E1212);
  static Color get warning => _active.brightness == Brightness.light
      ? const Color(0xFFB45309)
      : const Color(0xFFFFB300);
  static Color get onWarning => _active.brightness == Brightness.light
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF181202);
  static Color get warningSurface => _active.brightness == Brightness.light
      ? const Color(0xFFFEF3C7)
      : const Color(0xFF2E230B);

  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textTertiary => _active.textTertiary;
  static Color get textMuted => _active.textSecondary;

  static Color get borderSeparator => _active.borderSeparator;
  static Color get borderDefault => _active.borderDefault;
  static Color get borderSubtle => _active.borderSubtle;
  static Color get borderHover => _active.borderHover;
  static Color get actionCircleBg => _active.actionCircleBg;
}

/// 4px base spacing scale matching BoardUI spacing utilities & `.ui-craft/tokens.md`.
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

/// Varied BoardUI border-radius scale by element role.
abstract final class AppRadius {
  static const double xs = 4.0;
  static const double badge = 6.0;
  static const double sm = 8.0;
  static const double control = 10.0;
  static const double chip = 10.0;
  static const double card = 16.0;
  static const double panel = 20.0;
  static const double modal = 24.0;
  static const double pill = 9999.0;
}

/// Composite typography utilities aligned to BoardUI `styles/typography.css`
/// resolving colors dynamically from the active theme.
abstract final class AppType {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextStyle get title1Medium => TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.48,
        color: AppColors.textPrimary,
      );

  static TextStyle get title2Medium => TextStyle(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get title3Semibold => TextStyle(
        fontSize: 18,
        height: 26 / 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.27,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMedium => TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.16,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyRegular => TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get body2Medium => TextStyle(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption1Semibold => TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get caption1Medium => TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption1Regular => TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption2Medium => TextStyle(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );
}

/// BoardUI dark-mode layered shadows.
abstract final class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x24000000), blurRadius: 1, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> dropdown = [
    BoxShadow(color: Color(0x24000000), blurRadius: 1, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 4)),
  ];
}

/// Motion durations aligned to BoardUI's 150-300ms transition budget.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration focus = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 220);
}

/// Component-level tokens for episode and history list cards.
abstract final class AppCardTokens {
  static const double actionVisualSize = 36.0;
  static const double actionHitSize = 44.0;
  static const double actionIconSize = 18.0;
}

/// Shared Android/iOS system chrome helpers so exiting fullscreen playback
/// reliably restores native top status and bottom navigation bars.
abstract final class AppSystemUi {
  static SystemUiOverlayStyle get normalOverlayStyle {
    final isDark = AppColors.brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: AppColors.canvas,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: AppColors.brightness,
      systemNavigationBarColor: AppColors.canvas,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: AppColors.borderSeparator,
    );
  }

  static void restoreNormalChrome() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(normalOverlayStyle);
  }
}

/// Sleek, compact toggle row replacing bulky Material 3 default switches.
class CompactSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? titleColor;
  final Color? subtitleColor;

  const CompactSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.titleColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final activeTrack = AppColors.accent;
    final activeThumb = AppColors.onAccent;
    final inactiveTrack = AppColors.surfaceInteractive;
    final inactiveThumb = AppColors.textSecondary;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
      onTap: () => onChanged(!value),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: subtitleColor ?? AppColors.textMuted,
          fontSize: 11,
        ),
      ),
      trailing: Transform.scale(
        scale: 0.72,
        alignment: AlignmentDirectional.centerEnd,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeThumbColor: activeThumb,
          activeTrackColor: activeTrack,
          inactiveThumbColor: inactiveThumb,
          inactiveTrackColor: inactiveTrack,
          trackOutlineColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return activeTrack;
            return AppColors.borderDefault;
          }),
          trackOutlineWidth: const WidgetStatePropertyAll(1.0),
        ),
      ),
    );
  }
}
