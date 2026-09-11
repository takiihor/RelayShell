import 'package:flutter/foundation.dart';

/// Lifecycle for one command submitted through Conversation Mode.
enum ConversationCommandState { running, completed, interrupted, disconnected }

/// One command/output pair rendered by the conversation shell.
@immutable
class ConversationCommand {
  const ConversationCommand({
    required this.id,
    required this.command,
    required this.startedAt,
    required this.state,
    this.output = '',
    this.exitCode,
    this.completedAt,
    this.truncated = false,
  });

  final String id;
  final String command;
  final DateTime startedAt;
  final ConversationCommandState state;
  final String output;
  final int? exitCode;
  final DateTime? completedAt;
  final bool truncated;

  bool get isRunning => state == ConversationCommandState.running;

  Duration? get duration => completedAt?.difference(startedAt);

  ConversationCommand copyWith({
    ConversationCommandState? state,
    String? output,
    int? exitCode,
    bool clearExitCode = false,
    DateTime? completedAt,
    bool? truncated,
  }) => ConversationCommand(
    id: id,
    command: command,
    startedAt: startedAt,
    state: state ?? this.state,
    output: output ?? this.output,
    exitCode: clearExitCode ? null : exitCode ?? this.exitCode,
    completedAt: completedAt ?? this.completedAt,
    truncated: truncated ?? this.truncated,
  );
}
