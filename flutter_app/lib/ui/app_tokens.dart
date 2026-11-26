import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Primitive palette values aligned with BoardUI's Tailwind v4 neutral/red scale
/// (`src/react/styles/theme.css`).
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

  // Backwards-compatible gray aliases
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
  static const Color red950 = Color(0xFF450A0A);
  static const Color green500 = Color(0xFF46D369);
  static const Color lime500 = Color(0xFF84CC16);
}

/// Semantic color roles matching BoardUI `.dark` tokens.
abstract final class AppColors {
  static const Color canvas = AppPrimitives.neutral925; // bg-background-full
  static const Color surfaceSecondary = AppPrimitives.neutral900; // bg-background-secondary-default
  static const Color surfacePrimary = AppPrimitives.neutral800; // bg-background-primary-default
  static const Color surfaceRaised = Color(0xFF1B1B1B);
  static const Color surfaceOverlay = AppPrimitives.neutral900;
  static const Color surfaceInteractive = AppPrimitives.neutral800;
  static const Color surfaceSunken = Color(0xFF0E0E0E);
  static const Color cardBg = surfaceRaised;

  static const Color accent = AppPrimitives.red500;
  static const Color accentHover = AppPrimitives.red600;
  static const Color accentSoft = Color(0x24E50914);
  static const Color success = AppPrimitives.green500;
  static const Color successSurface = Color(0xFF132E19);
  static const Color successMutedSurface = Color(0xFF19241B);
  static const Color dangerSurface = Color(0xFF2E1212);
  static const Color warning = Color(0xFFFFB300);
  static const Color warningSurface = Color(0xFF2E230B);

  static const Color textPrimary = AppPrimitives.neutral50; // text-text-primary
  static const Color textSecondary = AppPrimitives.neutral400; // text-text-secondary
  static const Color textTertiary = AppPrimitives.neutral500; // text-text-tertiary
  static const Color textMuted = AppPrimitives.neutral500;
  static const Color borderSeparator = AppPrimitives.neutral800; // border-separator-border
  static const Color borderDefault = AppPrimitives.neutral700; // border-border-button-default
  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color borderHover = Color(0x28FFFFFF);
  static Color actionCircleBg = Colors.white.withValues(alpha: 0.05);
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
  static const double xs = 4.0; // Counter / tiny indicators
  static const double badge = 6.0; // Chip / Badge / segmented thumb
  static const double sm = 8.0; // Small buttons
  static const double control = 10.0; // BoardUI radius-2lg (buttons, inputs, segmented track)
  static const double chip = 10.0;
  static const double card = 16.0; // Cards & media frames
  static const double panel = 20.0; // BoardUI radius-2-5xl
  static const double modal = 24.0; // Bottom sheets & modals (rounded-3xl)
  static const double pill = 9999.0;
}

/// Composite typography utilities aligned to BoardUI `styles/typography.css`.
abstract final class AppType {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle title1Medium = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.48,
    color: AppColors.textPrimary,
  );

  static const TextStyle title2Medium = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle title3Semibold = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.27,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.16,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle body2Medium = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption1Semibold = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption1Medium = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption1Regular = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption2Medium = TextStyle(
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
  static const SystemUiOverlayStyle normalOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: AppColors.canvas,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: AppColors.borderSeparator,
  );

  static void restoreNormalChrome() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(normalOverlayStyle);
  }
}
