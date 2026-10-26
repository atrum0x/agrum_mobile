import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Based on the agrum_fe light tokens (src/index.css, OKLCH converted to sRGB) on a white page,
/// with a darker tea green as primary: FSD 8 asks for dark green headers and main buttons
/// with strong contrast outdoors.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF1E5631);
  static const foreground = Color(0xFF171C16);
  static const muted = Color(0xFFE8EBE4);
  static const mutedForeground = Color(0xFF60655D);
  static const accent = Color(0xFFDFEADA);
  static const accentForeground = Color(0xFF1C281A);
  static const border = Color(0xFFD9DCD4);
  static const ring = Color(0xFF5A8A68);
  static const destructive = Color(0xFFDC2626);

  /// FSD 8: amber for pending items (Waiting to send, offline).
  static const pending = Color(0xFFD97706);

  /// Amber that stays readable on the dark green header.
  static const pendingOnDark = Color(0xFFFBBF24);

  /// Window header (WindowAppBar): black on the left fading to the primary green on the right.
  static const headerGradient = LinearGradient(colors: [Colors.black, primary]);
}

ShadThemeData buildTheme() {
  return ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadGreenColorScheme.light(
      foreground: AppColors.foreground,
      cardForeground: AppColors.foreground,
      popoverForeground: AppColors.foreground,
      primary: AppColors.primary,
      primaryForeground: Colors.white,
      secondary: AppColors.muted,
      secondaryForeground: AppColors.foreground,
      muted: AppColors.muted,
      mutedForeground: AppColors.mutedForeground,
      accent: AppColors.accent,
      accentForeground: AppColors.accentForeground,
      destructive: AppColors.destructive,
      destructiveForeground: Colors.white,
      border: AppColors.border,
      input: AppColors.border,
      ring: AppColors.ring,
    ),
    radius: BorderRadius.circular(10),
    // FSD 8: at least 16 px text on mobile
    textTheme: ShadTextTheme(
      p: const TextStyle(fontSize: 16, height: 1.5),
      small: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      muted: const TextStyle(fontSize: 16, color: AppColors.mutedForeground),
    ),
  );
}
