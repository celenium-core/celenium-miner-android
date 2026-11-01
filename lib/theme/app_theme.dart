import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'typography.dart';

/// Builds the app theme from [Palette] and [TypeScale].
ThemeData buildCenTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  final scheme = const ColorScheme.dark(
    surface: Palette.field,
    primary: Palette.gold,
    onPrimary: Palette.ink,
    secondary: Palette.goldLight,
    onSecondary: Palette.ink,
    error: Palette.redDeep,
    onError: Palette.ink,
    onSurface: Palette.cream,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.field,
    canvasColor: Palette.field,
    splashColor: Palette.gold.withValues(alpha: 0.08),
    highlightColor: Palette.gold.withValues(alpha: 0.04),
    dividerColor: Palette.surfaceHigh,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Palette.gold,
      selectionColor: Palette.goldDim,
      selectionHandleColor: Palette.gold,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.field,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        fontFamily: TypeScale.displayFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.0,
        color: Palette.cream,
      ),
      iconTheme: IconThemeData(color: Palette.cream, size: 20),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: Palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Palette.cardRadius),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: Palette.ink,
        disabledBackgroundColor: Palette.surfaceHigh,
        disabledForegroundColor: Palette.slate,
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: TypeScale.bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.cream,
        side: const BorderSide(color: Palette.surfaceHigh),
        elevation: 0,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: TypeScale.bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.gold,
        textStyle: const TextStyle(
          fontFamily: TypeScale.bodyFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Palette.lg,
        vertical: 14,
      ),
      hintStyle: const TextStyle(
        fontFamily: TypeScale.monoFamily,
        fontSize: 13,
        color: Palette.slate,
      ),
      helperStyle: const TextStyle(
        fontFamily: TypeScale.bodyFamily,
        fontSize: 12,
        color: Palette.slate,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: const BorderSide(color: Palette.surfaceHigh),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: const BorderSide(color: Palette.gold),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: const BorderSide(color: Palette.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Palette.rowRadius),
        borderSide: const BorderSide(color: Palette.redDeep),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.surfaceHigh,
      contentTextStyle: TextStyle(
        fontFamily: TypeScale.bodyFamily,
        fontSize: 13,
        color: Palette.cream,
      ),
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Palette.ink : Palette.slate,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Palette.gold
            : Palette.surfaceHigh,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.gold,
      linearTrackColor: Palette.surfaceHigh,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Palette.cardRadius),
      ),
    ),
  );
}
