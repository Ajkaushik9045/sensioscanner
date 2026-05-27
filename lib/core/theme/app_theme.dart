import 'package:flutter/material.dart';

/// Sensio design tokens — health-app feel.
/// Palette: deep teal primary, cyan accent, clean off-white surface.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF00897B);       // teal 600
  static const Color primaryDark = Color(0xFF00695C);   // teal 800
  static const Color accent = Color(0xFF26C6DA);        // cyan 400
  static const Color accentDark = Color(0xFF0097A7);    // cyan 700

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);
  static const Color error = Color(0xFFE53935);

  // ── Surfaces (light) ───────────────────────────────────────────────────────
  static const Color background = Color(0xFFF4F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8F5F3);

  // ── Text (light) ───────────────────────────────────────────────────────────
  static const Color onBackground = Color(0xFF1A2E35);
  static const Color onSurface = Color(0xFF263238);
  static const Color onSurfaceMuted = Color(0xFF546E7A);

  // ── Surfaces (dark) ────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0D1F26);
  static const Color surfaceDark = Color(0xFF162830);
  static const Color surfaceVariantDark = Color(0xFF1E3A42);

  // ── Text (dark) ────────────────────────────────────────────────────────────
  static const Color onBackgroundDark = Color(0xFFE0F2F1);
  static const Color onSurfaceDark = Color(0xFFB2DFDB);
}

abstract final class AppRadius {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const BorderRadius card = BorderRadius.all(Radius.circular(large));
  static const BorderRadius button = BorderRadius.all(Radius.circular(medium));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(small));
}

abstract final class AppTheme {
  // ── Light ──────────────────────────────────────────────────────────────────
  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.surfaceVariant,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0F7FA),
      onSecondaryContainer: AppColors.accentDark,
      tertiary: AppColors.accentDark,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFB2EBF2),
      onTertiaryContainer: AppColors.accentDark,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFCDD2),
      onErrorContainer: const Color(0xFFB71C1C),
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.onSurfaceMuted,
      outline: const Color(0xFFB0BEC5),
      outlineVariant: const Color(0xFFCFD8DC),
      shadow: Colors.black12,
      scrim: Colors.black54,
      inverseSurface: AppColors.onBackground,
      onInverseSurface: AppColors.background,
      inversePrimary: AppColors.accent,
    );

    return _buildTheme(colorScheme, AppColors.background);
  }

  // ── Dark ───────────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.backgroundDark,
      primaryContainer: AppColors.surfaceVariantDark,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.primary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceVariantDark,
      onSecondaryContainer: AppColors.onBackgroundDark,
      tertiary: AppColors.accentDark,
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF1A3D45),
      onTertiaryContainer: AppColors.accent,
      error: const Color(0xFFEF9A9A),
      onError: AppColors.backgroundDark,
      errorContainer: const Color(0xFF4E1111),
      onErrorContainer: const Color(0xFFFFCDD2),
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onBackgroundDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceDark,
      outline: const Color(0xFF37474F),
      outlineVariant: const Color(0xFF263238),
      shadow: Colors.black54,
      scrim: Colors.black87,
      inverseSurface: AppColors.onBackgroundDark,
      onInverseSurface: AppColors.surfaceDark,
      inversePrimary: AppColors.primary,
    );

    return _buildTheme(colorScheme, AppColors.backgroundDark);
  }

  // ── Shared builder ─────────────────────────────────────────────────────────
  static ThemeData _buildTheme(ColorScheme cs, Color scaffoldBg) {
    final isLight = cs.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,

      // ── Typography ─────────────────────────────────────────────────────────
      // Using system font with fallback to system UI fonts; add Google Fonts
      // package in later phases if needed.
      textTheme: _textTheme(cs),

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? AppColors.surface : AppColors.surfaceDark,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.primary),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined Button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── Chips ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chip),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar ───────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.medium)),
        ),
        backgroundColor:
            isLight ? AppColors.onBackground : AppColors.surfaceVariantDark,
        contentTextStyle: const TextStyle(fontSize: 14),
      ),

      // ── List tile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Input decoration ───────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isLight ? AppColors.surfaceVariant : AppColors.surfaceVariantDark,
        border: const OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ── Text theme ─────────────────────────────────────────────────────────────
  static TextTheme _textTheme(ColorScheme cs) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
        color: cs.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
        color: cs.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: cs.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: cs.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: cs.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: cs.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: cs.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: cs.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: cs.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: cs.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: cs.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: cs.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: cs.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: cs.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
