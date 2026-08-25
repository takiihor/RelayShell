import 'package:flutter/material.dart';

import '../models/enums.dart';

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
  }) => StatusColors(
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
