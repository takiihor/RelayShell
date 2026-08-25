import 'package:flutter/foundation.dart';

import 'enums.dart';

/// A named terminal appearance preset (SPEC 23 `terminal_profiles`).
///
/// Presets let a user keep, say, a large high-contrast profile for outdoors and
/// a dense one for a tablet, and switch between them without re-tuning each
/// individual setting.
@immutable
class TerminalProfile {
  const TerminalProfile({
    required this.id,
    required this.name,
    required this.themeId,
    required this.fontFamily,
    required this.fontSize,
    required this.cursorStyle,
    required this.scrollbackLines,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String themeId;
  final String fontFamily;
  final double fontSize;
  final TerminalCursorStyle cursorStyle;
  final int scrollbackLines;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'theme_id': themeId,
    'font_family': fontFamily,
    'font_size': fontSize,
    'cursor_style': cursorStyle.storageValue,
    'scrollback_lines': scrollbackLines,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  factory TerminalProfile.fromRow(Map<String, Object?> row) => TerminalProfile(
    id: row['id']! as String,
    name: row['name']! as String,
    themeId: row['theme_id']! as String,
    fontFamily: row['font_family']! as String,
    fontSize: (row['font_size']! as num).toDouble(),
    cursorStyle: TerminalCursorStyle.fromStorage(
      row['cursor_style'] as String?,
    ),
    scrollbackLines: row['scrollback_lines']! as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
  );

  Map<String, Object?> toExportJson() => {
    'id': id,
    'name': name,
    'theme_id': themeId,
    'font_family': fontFamily,
    'font_size': fontSize,
    'cursor_style': cursorStyle.storageValue,
    'scrollback_lines': scrollbackLines,
  };

  @override
  bool operator ==(Object other) => other is TerminalProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
