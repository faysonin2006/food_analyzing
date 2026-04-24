import 'package:flutter/material.dart';

class AppTheme {
  static const Color atelierGreen = Color(0xFF1E6B47);
  static const Color atelierMint = Color(0xFFEAF9E5);
  static const Color atelierLime = Color(0xFF7FB35A);
  static const Color atelierWarmBg = Color(0xFFF7F4EE);
  static const Color atelierPanel = Color(0xFFF1EBE0);
  static const Color atelierPanelAlt = Color(0xFFD7CDBE);
  static const Color atelierText = Color(0xFF1F2620);
  static const Color atelierMuted = Color(0xFF58635B);
  static const Color atelierHint = Color(0xFF7B847C);
  static const Color atelierHoney = Color(0xFFA86A1D);

  static ThemeData light() {
    final scheme = const ColorScheme.light().copyWith(
      brightness: Brightness.light,
      primary: atelierGreen,
      onPrimary: Colors.white,
      secondary: atelierLime,
      onSecondary: const Color(0xFF18320C),
      error: const Color(0xFFB24E33),
      onError: Colors.white,
      surface: const Color(0xFFFFFCF8),
      onSurface: atelierText,
      tertiary: atelierHoney,
      onTertiary: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF9F5EE),
      surfaceContainer: const Color(0xFFF4EEE4),
      surfaceContainerHigh: const Color(0xFFF0E8DC),
      surfaceContainerHighest: atelierPanel,
      outlineVariant: atelierPanelAlt,
      onSurfaceVariant: atelierMuted,
      inverseSurface: atelierText,
      onInverseSurface: atelierWarmBg,
      shadow: const Color(0x14000000),
      scrim: const Color(0x66000000),
    );

    return _build(scheme: scheme, isDark: false);
  }

  static ThemeData dark() {
    final scheme = const ColorScheme.dark().copyWith(
      brightness: Brightness.dark,
      primary: const Color(0xFF8EE88A),
      onPrimary: const Color(0xFF0F4316),
      secondary: const Color(0xFFB9F474),
      onSecondary: const Color(0xFF2E4200),
      error: const Color(0xFFFF9A7A),
      onError: const Color(0xFF4B1100),
      surface: const Color(0xFF242520),
      onSurface: const Color(0xFFF2F1EB),
      tertiary: const Color(0xFFE8B96A),
      onTertiary: const Color(0xFF4B3100),
      surfaceContainerHighest: const Color(0xFF2F312B),
      outlineVariant: const Color(0xFF4B4E46),
      onSurfaceVariant: const Color(0xFFC8C7BF),
      inverseSurface: const Color(0xFFF2F1EB),
      onInverseSurface: const Color(0xFF1C1D18),
      shadow: Colors.black,
      scrim: const Color(0x99000000),
    );

    return _build(scheme: scheme, isDark: true);
  }

  static ThemeData _build({required ColorScheme scheme, required bool isDark}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF171814) : atelierWarmBg,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 56,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -2.8,
      ).copyWith(color: scheme.onSurface),
      displayMedium: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 42,
        fontWeight: FontWeight.w800,
        height: 1.06,
        letterSpacing: -1.8,
      ).copyWith(color: scheme.onSurface),
      headlineLarge: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -1.2,
      ).copyWith(color: scheme.onSurface),
      headlineMedium: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.8,
      ).copyWith(color: scheme.onSurface),
      headlineSmall: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: -0.5,
      ).copyWith(color: scheme.onSurface),
      titleLarge: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -0.3,
      ).copyWith(color: scheme.onSurface),
      titleMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ).copyWith(color: scheme.onSurface),
      bodyLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ).copyWith(color: scheme.onSurface),
      bodyMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ).copyWith(color: scheme.onSurface),
      bodySmall: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ).copyWith(color: scheme.onSurfaceVariant),
      labelLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ).copyWith(color: scheme.onSurface),
      labelMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 1.0,
      ).copyWith(color: scheme.onSurfaceVariant),
      labelSmall: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 1.0,
      ).copyWith(color: scheme.onSurfaceVariant),
    );

    final outline = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.75 : 0.9,
    );
    final cardShadow = [
      BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.24)
            : atelierGreen.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
    ];

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.86)
            : scheme.surfaceContainerLow,
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: atelierHint),
        prefixIconColor: atelierHint,
        suffixIconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.08),
          disabledForegroundColor: scheme.onSurfaceVariant.withValues(
            alpha: 0.55,
          ),
          minimumSize: const Size(0, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? scheme.onSurface : scheme.primary,
          side: BorderSide(color: outline.withValues(alpha: 0.28)),
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium,
          backgroundColor: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : scheme.surface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.titleMedium,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: isDark
            ? Color.alphaBlend(
                scheme.surfaceContainerHighest.withValues(alpha: 0.78),
                scheme.surface,
              )
            : scheme.surfaceContainerLow,
        selectedColor: isDark
            ? scheme.primary.withValues(alpha: 0.22)
            : scheme.primary.withValues(alpha: 0.14),
        disabledColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.56)
            : scheme.surfaceContainer,
        labelStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? scheme.onSurface : scheme.primary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(
          color: (isDark ? scheme.outlineVariant : atelierPanelAlt).withValues(
            alpha: 0.72,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: outline.withValues(alpha: 0.5)),
      iconTheme: IconThemeData(color: scheme.onSurface),
      extensions: <ThemeExtension<dynamic>>[
        _AtelierShadowTheme(shadows: cardShadow),
      ],
    );
  }
}

class _AtelierShadowTheme extends ThemeExtension<_AtelierShadowTheme> {
  const _AtelierShadowTheme({required this.shadows});

  final List<BoxShadow> shadows;

  @override
  _AtelierShadowTheme copyWith({List<BoxShadow>? shadows}) {
    return _AtelierShadowTheme(shadows: shadows ?? this.shadows);
  }

  @override
  _AtelierShadowTheme lerp(
    ThemeExtension<_AtelierShadowTheme>? other,
    double t,
  ) {
    if (other is! _AtelierShadowTheme) return this;
    return t < 0.5 ? this : other;
  }
}
