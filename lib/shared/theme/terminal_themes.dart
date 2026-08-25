import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// A selectable terminal colour scheme (SPEC 21 Appearance), available to
/// terminal-facing features without importing the app composition layer.
@immutable
class NamedTerminalTheme {
  const NamedTerminalTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.theme,
  });

  final String id;
  final String name;
  final bool isDark;
  final TerminalTheme theme;
}

/// The bundled terminal colour schemes.
///
/// Every palette keeps the sixteen ANSI colours distinguishable from each other
/// and from the background, because `ls`, `git` and build tools use them to
/// carry meaning. Contrast is checked against the background, not against
/// white.
class TerminalThemeCatalog {
  const TerminalThemeCatalog._();

  static const String defaultDarkId = 'relay_dark';
  static const String defaultLightId = 'relay_light';

  static const NamedTerminalTheme relayDark = NamedTerminalTheme(
    id: defaultDarkId,
    name: 'Relay Dark',
    isDark: true,
    theme: TerminalTheme(
      cursor: Color(0xFF7AA2F7),
      selection: Color(0x553D6DF0),
      foreground: Color(0xFFD7DCE5),
      background: Color(0xFF11141B),
      black: Color(0xFF2A2F3A),
      red: Color(0xFFF07178),
      green: Color(0xFF98C379),
      yellow: Color(0xFFE5C07B),
      blue: Color(0xFF61AFEF),
      magenta: Color(0xFFC678DD),
      cyan: Color(0xFF56B6C2),
      white: Color(0xFFD7DCE5),
      brightBlack: Color(0xFF5C6370),
      brightRed: Color(0xFFFF7B86),
      brightGreen: Color(0xFFB5E890),
      brightYellow: Color(0xFFFFD787),
      brightBlue: Color(0xFF82C7FF),
      brightMagenta: Color(0xFFDDA0F0),
      brightCyan: Color(0xFF74D3DE),
      brightWhite: Color(0xFFF2F5FA),
      searchHitBackground: Color(0xFF3D6DF0),
      searchHitBackgroundCurrent: Color(0xFFE5C07B),
      searchHitForeground: Color(0xFF11141B),
    ),
  );

  static const NamedTerminalTheme relayLight = NamedTerminalTheme(
    id: defaultLightId,
    name: 'Relay Light',
    isDark: false,
    theme: TerminalTheme(
      cursor: Color(0xFF3D6DF0),
      selection: Color(0x333D6DF0),
      foreground: Color(0xFF1F2430),
      background: Color(0xFFFBFCFE),
      black: Color(0xFF1F2430),
      red: Color(0xFFC0392B),
      green: Color(0xFF2E7D32),
      yellow: Color(0xFF9A6700),
      blue: Color(0xFF1D4ED8),
      magenta: Color(0xFF8E44AD),
      cyan: Color(0xFF0E7490),
      white: Color(0xFF6B7280),
      brightBlack: Color(0xFF4B5563),
      brightRed: Color(0xFFDC2626),
      brightGreen: Color(0xFF15803D),
      brightYellow: Color(0xFFB45309),
      brightBlue: Color(0xFF2563EB),
      brightMagenta: Color(0xFFA855F7),
      brightCyan: Color(0xFF0891B2),
      brightWhite: Color(0xFF111827),
      searchHitBackground: Color(0xFFBFD4FF),
      searchHitBackgroundCurrent: Color(0xFFFFD787),
      searchHitForeground: Color(0xFF1F2430),
    ),
  );

  static const NamedTerminalTheme solarizedDark = NamedTerminalTheme(
    id: 'solarized_dark',
    name: 'Solarized Dark',
    isDark: true,
    theme: TerminalTheme(
      cursor: Color(0xFF93A1A1),
      selection: Color(0x55268BD2),
      foreground: Color(0xFF93A1A1),
      background: Color(0xFF002B36),
      black: Color(0xFF073642),
      red: Color(0xFFDC322F),
      green: Color(0xFF859900),
      yellow: Color(0xFFB58900),
      blue: Color(0xFF268BD2),
      magenta: Color(0xFFD33682),
      cyan: Color(0xFF2AA198),
      white: Color(0xFFEEE8D5),
      brightBlack: Color(0xFF586E75),
      brightRed: Color(0xFFCB4B16),
      brightGreen: Color(0xFF93A1A1),
      brightYellow: Color(0xFF839496),
      brightBlue: Color(0xFF657B83),
      brightMagenta: Color(0xFF6C71C4),
      brightCyan: Color(0xFF93A1A1),
      brightWhite: Color(0xFFFDF6E3),
      searchHitBackground: Color(0xFF268BD2),
      searchHitBackgroundCurrent: Color(0xFFB58900),
      searchHitForeground: Color(0xFF002B36),
    ),
  );

  static const NamedTerminalTheme highContrast = NamedTerminalTheme(
    id: 'high_contrast',
    name: 'High Contrast',
    isDark: true,
    theme: TerminalTheme(
      cursor: Color(0xFFFFFFFF),
      selection: Color(0x66FFFFFF),
      foreground: Color(0xFFFFFFFF),
      background: Color(0xFF000000),
      black: Color(0xFF000000),
      red: Color(0xFFFF5F5F),
      green: Color(0xFF5FFF5F),
      yellow: Color(0xFFFFFF5F),
      blue: Color(0xFF5F9FFF),
      magenta: Color(0xFFFF5FFF),
      cyan: Color(0xFF5FFFFF),
      white: Color(0xFFE0E0E0),
      brightBlack: Color(0xFF808080),
      brightRed: Color(0xFFFF8787),
      brightGreen: Color(0xFF87FF87),
      brightYellow: Color(0xFFFFFF87),
      brightBlue: Color(0xFF87BFFF),
      brightMagenta: Color(0xFFFF87FF),
      brightCyan: Color(0xFF87FFFF),
      brightWhite: Color(0xFFFFFFFF),
      searchHitBackground: Color(0xFF0000FF),
      searchHitBackgroundCurrent: Color(0xFFFFFF00),
      searchHitForeground: Color(0xFF000000),
    ),
  );

  static const List<NamedTerminalTheme> all = [
    relayDark,
    relayLight,
    solarizedDark,
    highContrast,
  ];

  static NamedTerminalTheme byId(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => relayDark);
}

/// Monospace fonts offered in Settings.
///
/// These are the families bundled with, or reliably present on, the target
/// platforms; a family the device lacks silently falls back and confuses the
/// user, so the list stays short and honest.
class TerminalFonts {
  const TerminalFonts._();

  static const List<String> available = [
    'RobotoMono',
    'Menlo',
    'Courier New',
    'monospace',
  ];

  static const List<String> fallbacks = [
    'RobotoMono',
    'Menlo',
    'DejaVu Sans Mono',
    'Noto Sans Mono CJK SC',
    'monospace',
  ];

  static const double minSize = 8;
  static const double maxSize = 28;
}
