import 'package:flutter/material.dart';

import '../../shared/models/enums.dart';

/// Application theming (SPEC 39).
///
/// The visual target is a modern utility, not a hacker-themed novelty: flat
/// surfaces, high information density, one clear primary action per card, and
/// status carried by a labelled colour rather than colour alone (SPEC 37).
class AppTheme {
  const AppTheme._();

  /// A restrained blue-grey. Distinct enough to brand the app without
  /// competing with the semantic status colours, which must stand out.
  static const Color seed = Color(0xFF3D6DF0);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeMode themeModeFrom(AppThemeMode mode) => switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Colours for the semantic states in SPEC 39.
///
/// Exposed through the theme rather than hard-coded at call sites so light and
/// dark stay legible, and always paired with a text label or icon in the UI so
/// the meaning does not rest on colour alone (SPEC 37).
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.connected,
    required this.connecting,
    required this.warning,
    required this.error,
    required this.inactive,
  });

  final Color connected;
  final Color connecting;
  final Color warning;
  final Color error;
  final Color inactive;

  factory StatusColors.of(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return StatusColors(
      connected: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
      connecting: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      warning: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      inactive: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );
  }

  Color forStatus(SemanticStatus status) => switch (status) {
        SemanticStatus.connected => connected,
        SemanticStatus.connecting => connecting,
        SemanticStatus.warning => warning,
        SemanticStatus.error => error,
        SemanticStatus.inactive => inactive,
      };

  @override
  StatusColors copyWith({
    Color? connected,
    Color? connecting,
    Color? warning,
    Color? error,
    Color? inactive,
  }) =>
      StatusColors(
        connected: connected ?? this.connected,
        connecting: connecting ?? this.connecting,
        warning: warning ?? this.warning,
        error: error ?? this.error,
        inactive: inactive ?? this.inactive,
      );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      connected: Color.lerp(connected, other.connected, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      inactive: Color.lerp(inactive, other.inactive, t)!,
    );
  }
}

extension StatusColorsContext on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ??
      StatusColors.of(Theme.of(this).brightness);
}
