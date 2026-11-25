import 'package:flutter/material.dart';

/// Primitive palette values for dTVSteams (Netflix Edition).
abstract final class AppPrimitives {
  static const Color gray950 = Color(0xFF0F0F0F);
  static const Color gray900 = Color(0xFF141414);
  static const Color gray850 = Color(0xFF181818);
  static const Color gray800 = Color(0xFF202020);
  static const Color gray750 = Color(0xFF262626);
  static const Color gray700 = Color(0xFF2F2F2F);
  static const Color gray600 = Color(0xFF383838);

  static const Color red500 = Color(0xFFE50914);
  static const Color red600 = Color(0xFFB80710);
  static const Color green500 = Color(0xFF46D369);
}

/// Semantic color roles mapped from primitives.
abstract final class AppColors {
  static const Color canvas = AppPrimitives.gray900;
  static const Color surfaceRaised = AppPrimitives.gray800;
  static const Color surfaceOverlay = AppPrimitives.gray850;
  static const Color surfaceInteractive = AppPrimitives.gray750;
  static const Color cardBg = AppPrimitives.gray800;

  static const Color accent = AppPrimitives.red500;
  static const Color accentHover = AppPrimitives.red600;
  static const Color success = AppPrimitives.green500;
  static const Color successSurface = Color(0xFF13381B);
  static const Color successMutedSurface = Color(0xFF1F2E22);
  static const Color dangerSurface = Color(0xFF331111);
  static const Color surfaceSunken = Color(0xFF191919);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color borderSubtle = Colors.white12;
  static Color actionCircleBg = Colors.white.withValues(alpha: 0.04);
}

/// 4px base spacing scale matching `.ui-craft/tokens.md`.
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

/// Element-role border radii.
abstract final class AppRadius {
  static const double badge = 4.0;
  static const double chip = 6.0;
  static const double card = 8.0;
  static const double modal = 16.0;
}

/// Motion durations aligned to the 100-400ms UI transition band.
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
