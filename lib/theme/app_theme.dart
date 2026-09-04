import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// Builds the app's two themes from [LedgerColors].
///
/// Every Material component that ships with a recognisable default — the
/// tinted app bar, the pill tab indicator, the elevated card, the rounded
/// chip, the stadium button — is overridden here rather than worked around
/// screen by screen.
abstract final class AppTheme {
  static ThemeData light() => _build(LedgerColors.light, Brightness.light);
  static ThemeData dark() => _build(LedgerColors.dark, Brightness.dark);

  static ThemeData _build(LedgerColors c, Brightness brightness) {
    final text = _textTheme(c);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.accent,
      onSecondary: c.onInk,
      error: c.danger,
      onError: c.onInk,
      surface: c.panel,
      onSurface: c.ink,
      surfaceContainerHighest: c.well,
      onSurfaceVariant: c.inkMuted,
      outline: c.rule,
      outlineVariant: c.rule,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.ground,
      canvasColor: c.ground,
      dividerColor: c.rule,
      textTheme: text,
      fontFamily: Faces.body,

      // Flat header on the ground colour: no tint, no shadow, no
      // scroll-under recolour.
      appBarTheme: AppBarTheme(
        backgroundColor: c.ground,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: Space.gutter,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      dividerTheme: DividerThemeData(color: c.rule, thickness: 1, space: 1),

      // Value, not shadow, separates a panel from the ground.
      cardTheme: CardThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.block,
          side: BorderSide(color: c.rule),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: c.rule),
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        labelStyle: text.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: Space.snug,
          vertical: Space.tight,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.well,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.step,
          vertical: 15,
        ),
        hintStyle: text.bodyMedium?.copyWith(color: c.inkFaint),
        labelStyle: text.labelSmall?.copyWith(color: c.inkMuted),
        floatingLabelStyle: text.labelSmall?.copyWith(color: c.ink),
        errorStyle: text.labelSmall?.copyWith(color: c.danger),
        border: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.rule),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.rule),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.ruleStrong, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),

      // Squared-off buttons in ink. The accent never fills a button — it
      // belongs to progress.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.ink,
          foregroundColor: c.onInk,
          disabledBackgroundColor: c.well,
          disabledForegroundColor: c.inkFaint,
          minimumSize: const Size(0, kTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          shape: const RoundedRectangleBorder(borderRadius: Radii.field),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.ruleStrong),
          minimumSize: const Size(0, kTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          shape: const RoundedRectangleBorder(borderRadius: Radii.field),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(0, kTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: Space.step),
          shape: const RoundedRectangleBorder(borderRadius: Radii.field),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size(kTapTarget, kTapTarget),
          shape: const RoundedRectangleBorder(borderRadius: Radii.field),
        ),
      ),
      iconTheme: IconThemeData(color: c.ink, size: 20),

      dialogTheme: DialogThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.block,
          side: BorderSide(color: c.rule),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: c.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.field,
          side: BorderSide(color: c.rule),
        ),
        textStyle: text.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInk),
        actionTextColor: c.onInk,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.field),
        insetPadding: const EdgeInsets.all(Space.step),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.well,
        circularTrackColor: c.well,
        linearMinHeight: 3,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: c.inkMuted,
        textColor: c.ink,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: c.inkMuted),
        shape: const RoundedRectangleBorder(borderRadius: Radii.field),
        minVerticalPadding: Space.step,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        headerBackgroundColor: c.ink,
        headerForegroundColor: c.onInk,
        dayStyle: text.bodyMedium?.copyWith(fontFeatures: kTabular),
        shape: const RoundedRectangleBorder(borderRadius: Radii.block),
        todayBorder: BorderSide(color: c.ruleStrong),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.ink,
        selectionColor: c.well,
        selectionHandleColor: c.ruleStrong,
      ),
    );
  }

  /// Three faces, three jobs. Condensed carries titles, Roboto carries
  /// prose, monospace carries every number and label.
  static TextTheme _textTheme(LedgerColors c) {
    TextStyle display(double size, FontWeight weight, double tracking) =>
        TextStyle(
          fontFamily: Faces.display,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: tracking,
          height: 1.12,
          color: c.ink,
          fontFeatures: kTabular,
        );

    TextStyle body(double size, Color color) => TextStyle(
          fontFamily: Faces.body,
          fontSize: size,
          height: 1.45,
          color: color,
          fontFeatures: kTabular,
        );

    TextStyle utility(double size, Color color, {FontWeight? weight}) =>
        TextStyle(
          fontFamily: Faces.utility,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: 0.8,
          height: 1.3,
          color: color,
          fontFeatures: kTabular,
        );

    return TextTheme(
      displaySmall: display(34, FontWeight.w700, -0.6),
      headlineMedium: display(28, FontWeight.w700, -0.4),
      headlineSmall: display(22, FontWeight.w700, -0.2),
      titleLarge: display(20, FontWeight.w700, -0.1),
      titleMedium: display(17, FontWeight.w700, 0),
      titleSmall: display(15, FontWeight.w600, 0),
      bodyLarge: body(15, c.ink),
      bodyMedium: body(14, c.ink),
      bodySmall: body(13, c.inkMuted),
      labelLarge: utility(13, c.ink, weight: FontWeight.w600),
      labelMedium: utility(12, c.inkMuted),
      labelSmall: utility(11, c.inkMuted),
    );
  }
}
