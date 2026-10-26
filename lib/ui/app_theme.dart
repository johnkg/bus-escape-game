import 'package:flutter/material.dart';

import 'ui_style.dart';

/// The app-wide Material theme: dark clay surfaces, rounded fonts.
ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accent,
        secondary: AppColors.secondary,
        surface: AppColors.card,
        onSurface: Colors.white,
        onSurfaceVariant: AppColors.textMuted,
        error: AppColors.warning,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: Fonts.body,
    scaffoldBackgroundColor: AppColors.background,
  );
  const displayStyle = TextStyle(
    fontFamily: Fonts.display,
    fontWeight: FontWeight.w700,
  );
  final clayShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.card),
    side: const BorderSide(color: AppColors.cardRim, width: Clay.rim),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: base.textTheme.displayLarge?.merge(displayStyle),
      displayMedium: base.textTheme.displayMedium?.merge(displayStyle),
      displaySmall: base.textTheme.displaySmall?.merge(displayStyle),
      headlineLarge: base.textTheme.headlineLarge?.merge(displayStyle),
      headlineMedium: base.textTheme.headlineMedium?.merge(displayStyle),
      headlineSmall: base.textTheme.headlineSmall?.merge(displayStyle),
      titleLarge: base.textTheme.titleLarge?.merge(displayStyle),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      shape: clayShape,
      titleTextStyle: displayStyle.copyWith(
        color: Colors.white,
        fontSize: FontSizes.title,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: Fonts.body,
        color: AppColors.textMuted,
        fontSize: FontSizes.label,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.go
            : AppColors.muted,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: displayStyle.copyWith(fontSize: FontSizes.label),
        minimumSize: const Size(minTouchTarget, minTouchTarget),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.cardRim),
  );
}
