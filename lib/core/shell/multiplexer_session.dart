import 'package:flutter/foundation.dart';

import '../../shared/models/enums.dart';

/// A persistent session as reported by the remote machine (SPEC 11.4).
///
/// Shared by every backend: a tmux session and a Herdr session carry the same
/// facts the UI needs, and the session list should not care which produced it.
@immutable
class MultiplexerSession {
  const MultiplexerSession({
    required this.name,
    required this.windows,
    required this.attached,
    this.created,
    this.directory,
  });

  final String name;

  /// Windows (tmux) or tabs (Herdr). Zero when the backend does not report it.
  final int windows;

  final bool attached;
  final DateTime? created;

  /// Working directory of the session, when the backend reports one.
  final String? directory;

  /// True when this session was created by the app under [prefix].
  bool isManagedBy(String prefix) => name.startsWith('$prefix-');

  @override
  bool operator ==(Object other) =>
      other is MultiplexerSession && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Raised when the selected multiplexer is not installed on the remote machine.
class MultiplexerUnavailableException implements Exception {
  const MultiplexerUnavailableException(this.kind);

  final MultiplexerKind kind;

  @override
  String toString() => '${kind.label} is not installed on this computer.';
}

/// Raised when a management command fails on the remote side.
class MultiplexerOperationException implements Exception {
  const MultiplexerOperationException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => message;
}
