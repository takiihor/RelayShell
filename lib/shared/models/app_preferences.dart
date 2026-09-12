import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'enums.dart';

const Object _unset = Object();

/// All user-configurable settings (SPEC 21).
///
/// Persisted as a flat key/value table so that adding a preference never needs
/// a schema migration. Unknown/missing keys always fall back to the default.
@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = AppThemeMode.system,
    this.terminalThemeId = 'relay_dark',
    this.terminalFontFamily = 'RobotoMono',
    this.terminalFontSize = 13,
    this.cursorStyle = TerminalCursorStyle.block,
    this.hapticFeedback = true,
    this.keepScreenAwake = true,
    this.scrollbackLines = 2000,
    this.accessoryKeyRows = defaultAccessoryRows,
    this.copyOnSelect = false,
    this.confirmMultilinePaste = true,
    this.defaultSessionMode = SessionMode.direct,
    this.keepaliveSeconds = 30,
    this.connectTimeoutSeconds = 15,
    this.authTimeoutSeconds = 30,
    this.terminalType = 'xterm-256color',
    this.reconnectBehavior = ReconnectBehavior.autoBounded,
    this.maxReconnectAttempts = 3,
    this.appLockEnabled = false,
    this.appLockTimeout = AppLockTimeout.immediately,
    this.credentialBiometricDefault = false,
    this.clearClipboardAfterSecrets = true,
    this.clearClipboardSeconds = 45,
    this.tmuxSessionPrefix = 'rdc',
    this.defaultMultiplexer = MultiplexerKind.tmux,
    this.locale,
  });

  /// Mobile coding-agent defaults shared by Terminal and Conversation Mode.
  ///
  /// CTRL/SHIFT/ALT/TAB are deliberately first-class because Herdr, Codex,
  /// Claude Code and terminal TUIs depend on real modifier sequences that are
  /// awkward or impossible to produce reliably from a phone keyboard. The
  /// second row keeps shell punctuation and explicit scroll/interrupt controls
  /// one tap away.
  static const List<List<String>> defaultAccessoryRows = [
    ['esc', 'ctrl', 'shift', 'alt', 'tab', 'up', 'left', 'down', 'right'],
    [
      'wheel_up',
      'wheel_down',
      'slash',
      'tilde',
      'pipe',
      'ampersand',
      'dash',
      'underscore',
      'colon',
      'ctrl_c',
    ],
  ];

  final AppThemeMode themeMode;
  final String terminalThemeId;
  final String terminalFontFamily;
  final double terminalFontSize;
  final TerminalCursorStyle cursorStyle;
  final bool hapticFeedback;
  final bool keepScreenAwake;

  final int scrollbackLines;
  final List<List<String>> accessoryKeyRows;
  final bool copyOnSelect;
  final bool confirmMultilinePaste;
  final SessionMode defaultSessionMode;

  final int keepaliveSeconds;
  final int connectTimeoutSeconds;
  final int authTimeoutSeconds;
  final String terminalType;
  final ReconnectBehavior reconnectBehavior;
  final int maxReconnectAttempts;

  final bool appLockEnabled;
  final AppLockTimeout appLockTimeout;
  final bool credentialBiometricDefault;
  final bool clearClipboardAfterSecrets;
  final int clearClipboardSeconds;

  final String tmuxSessionPrefix;

  /// Backend pre-selected when adding a computer. Per-host from then on.
  final MultiplexerKind defaultMultiplexer;

  /// `null` means follow the device locale.
  final String? locale;

  Duration get keepalive => Duration(seconds: keepaliveSeconds);
  Duration get connectTimeout => Duration(seconds: connectTimeoutSeconds);
  Duration get authTimeout => Duration(seconds: authTimeoutSeconds);

  AppPreferences copyWith({
    AppThemeMode? themeMode,
    String? terminalThemeId,
    String? terminalFontFamily,
    double? terminalFontSize,
    TerminalCursorStyle? cursorStyle,
    bool? hapticFeedback,
    bool? keepScreenAwake,
    int? scrollbackLines,
    List<List<String>>? accessoryKeyRows,
    bool? copyOnSelect,
    bool? confirmMultilinePaste,
    SessionMode? defaultSessionMode,
    int? keepaliveSeconds,
    int? connectTimeoutSeconds,
    int? authTimeoutSeconds,
    String? terminalType,
    ReconnectBehavior? reconnectBehavior,
    int? maxReconnectAttempts,
    bool? appLockEnabled,
    AppLockTimeout? appLockTimeout,
    bool? credentialBiometricDefault,
    bool? clearClipboardAfterSecrets,
    int? clearClipboardSeconds,
    String? tmuxSessionPrefix,
    MultiplexerKind? defaultMultiplexer,
    Object? locale = _unset,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    terminalThemeId: terminalThemeId ?? this.terminalThemeId,
    terminalFontFamily: terminalFontFamily ?? this.terminalFontFamily,
    terminalFontSize: terminalFontSize ?? this.terminalFontSize,
    cursorStyle: cursorStyle ?? this.cursorStyle,
    hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    scrollbackLines: scrollbackLines ?? this.scrollbackLines,
    accessoryKeyRows: accessoryKeyRows ?? this.accessoryKeyRows,
    copyOnSelect: copyOnSelect ?? this.copyOnSelect,
    confirmMultilinePaste: confirmMultilinePaste ?? this.confirmMultilinePaste,
    defaultSessionMode: defaultSessionMode ?? this.defaultSessionMode,
    keepaliveSeconds: keepaliveSeconds ?? this.keepaliveSeconds,
    connectTimeoutSeconds: connectTimeoutSeconds ?? this.connectTimeoutSeconds,
    authTimeoutSeconds: authTimeoutSeconds ?? this.authTimeoutSeconds,
    terminalType: terminalType ?? this.terminalType,
    reconnectBehavior: reconnectBehavior ?? this.reconnectBehavior,
    maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
    appLockEnabled: appLockEnabled ?? this.appLockEnabled,
    appLockTimeout: appLockTimeout ?? this.appLockTimeout,
    credentialBiometricDefault:
        credentialBiometricDefault ?? this.credentialBiometricDefault,
    clearClipboardAfterSecrets:
        clearClipboardAfterSecrets ?? this.clearClipboardAfterSecrets,
    clearClipboardSeconds: clearClipboardSeconds ?? this.clearClipboardSeconds,
    tmuxSessionPrefix: tmuxSessionPrefix ?? this.tmuxSessionPrefix,
    defaultMultiplexer: defaultMultiplexer ?? this.defaultMultiplexer,
    locale: locale == _unset ? this.locale : locale as String?,
  );

  Map<String, String> toMap() => {
    'theme_mode': themeMode.storageValue,
    'terminal_theme_id': terminalThemeId,
    'terminal_font_family': terminalFontFamily,
    'terminal_font_size': terminalFontSize.toString(),
    'cursor_style': cursorStyle.storageValue,
    'haptic_feedback': hapticFeedback.toString(),
    'keep_screen_awake': keepScreenAwake.toString(),
    'scrollback_lines': scrollbackLines.toString(),
    'accessory_key_rows': jsonEncode(accessoryKeyRows),
    'copy_on_select': copyOnSelect.toString(),
    'confirm_multiline_paste': confirmMultilinePaste.toString(),
    'default_session_mode': defaultSessionMode.storageValue,
    'keepalive_seconds': keepaliveSeconds.toString(),
    'connect_timeout_seconds': connectTimeoutSeconds.toString(),
    'auth_timeout_seconds': authTimeoutSeconds.toString(),
    'terminal_type': terminalType,
    'reconnect_behavior': reconnectBehavior.storageValue,
    'max_reconnect_attempts': maxReconnectAttempts.toString(),
    'app_lock_enabled': appLockEnabled.toString(),
    'app_lock_timeout': appLockTimeout.storageValue,
    'credential_biometric_default': credentialBiometricDefault.toString(),
    'clear_clipboard_after_secrets': clearClipboardAfterSecrets.toString(),
    'clear_clipboard_seconds': clearClipboardSeconds.toString(),
    'tmux_session_prefix': tmuxSessionPrefix,
    'default_multiplexer': defaultMultiplexer.storageValue,
    'locale': ?locale,
  };

  factory AppPreferences.fromMap(Map<String, String> map) {
    const fallback = AppPreferences();
    bool boolAt(String key, bool orElse) => switch (map[key]) {
      'true' => true,
      'false' => false,
      _ => orElse,
    };
    int intAt(String key, int orElse, {required int min, required int max}) {
      final value = int.tryParse(map[key] ?? '') ?? orElse;
      return value.clamp(min, max);
    }

    double doubleAt(
      String key,
      double orElse, {
      required double min,
      required double max,
    }) {
      final value = double.tryParse(map[key] ?? '') ?? orElse;
      return value.clamp(min, max);
    }

    return AppPreferences(
      themeMode: AppThemeMode.fromStorage(map['theme_mode']),
      terminalThemeId: map['terminal_theme_id'] ?? fallback.terminalThemeId,
      terminalFontFamily:
          map['terminal_font_family'] ?? fallback.terminalFontFamily,
      terminalFontSize: doubleAt(
        'terminal_font_size',
        fallback.terminalFontSize,
        min: 8,
        max: 28,
      ),
      cursorStyle: TerminalCursorStyle.fromStorage(map['cursor_style']),
      hapticFeedback: boolAt('haptic_feedback', fallback.hapticFeedback),
      keepScreenAwake: boolAt('keep_screen_awake', fallback.keepScreenAwake),
      scrollbackLines: intAt(
        'scrollback_lines',
        fallback.scrollbackLines,
        min: 200,
        max: 20000,
      ),
      accessoryKeyRows: _decodeRows(map['accessory_key_rows']),
      copyOnSelect: boolAt('copy_on_select', fallback.copyOnSelect),
      confirmMultilinePaste: boolAt(
        'confirm_multiline_paste',
        fallback.confirmMultilinePaste,
      ),
      defaultSessionMode: SessionMode.fromStorage(map['default_session_mode']),
      keepaliveSeconds: intAt(
        'keepalive_seconds',
        fallback.keepaliveSeconds,
        min: 5,
        max: 120,
      ),
      connectTimeoutSeconds: intAt(
        'connect_timeout_seconds',
        fallback.connectTimeoutSeconds,
        min: 5,
        max: 60,
      ),
      authTimeoutSeconds: intAt(
        'auth_timeout_seconds',
        fallback.authTimeoutSeconds,
        min: 10,
        max: 120,
      ),
      terminalType: map['terminal_type'] ?? fallback.terminalType,
      reconnectBehavior: ReconnectBehavior.fromStorage(
        map['reconnect_behavior'],
      ),
      maxReconnectAttempts: intAt(
        'max_reconnect_attempts',
        fallback.maxReconnectAttempts,
        min: 0,
        max: 10,
      ),
      appLockEnabled: boolAt('app_lock_enabled', fallback.appLockEnabled),
      appLockTimeout: AppLockTimeout.fromStorage(map['app_lock_timeout']),
      credentialBiometricDefault: boolAt(
        'credential_biometric_default',
        fallback.credentialBiometricDefault,
      ),
      clearClipboardAfterSecrets: boolAt(
        'clear_clipboard_after_secrets',
        fallback.clearClipboardAfterSecrets,
      ),
      clearClipboardSeconds: intAt(
        'clear_clipboard_seconds',
        fallback.clearClipboardSeconds,
        min: 0,
        max: 3600,
      ),
      tmuxSessionPrefix:
          map['tmux_session_prefix'] ?? fallback.tmuxSessionPrefix,
      defaultMultiplexer: MultiplexerKind.fromStorage(
        map['default_multiplexer'],
      ),
      locale: map['locale'],
    );
  }

  static List<List<String>> _decodeRows(String? raw) {
    if (raw == null || raw.isEmpty) return defaultAccessoryRows;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return defaultAccessoryRows;
      final rows = <List<String>>[];
      for (final row in decoded.take(2)) {
        if (row is List) {
          rows.add(
            row
                .take(12)
                .map((e) => e.toString().trim())
                .where((key) => key.isNotEmpty && key.length <= 32)
                .toList(growable: false),
          );
        }
      }
      return rows.any((row) => row.isEmpty) || rows.isEmpty
          ? defaultAccessoryRows
          : rows;
    } on FormatException {
      return defaultAccessoryRows;
    }
  }
}
