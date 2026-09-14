import 'package:flutter/foundation.dart';

/// Lifecycle for one command submitted through Conversation Mode.
enum ConversationCommandState { running, completed, interrupted, disconnected }

/// Text the user sends to a command that is still running, e.g. a Herdr/Codex
/// prompt or a response to an interactive CLI question.
@immutable
class ConversationProcessInput {
  const ConversationProcessInput({required this.text, required this.sentAt});

  final String text;
  final DateTime sentAt;
}

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
    this.interactiveHint = false,
    this.fullScreenDetected = false,
    this.processInputs = const [],
  });

  final String id;
  final String command;
  final DateTime startedAt;
  final ConversationCommandState state;
  final String output;
  final int? exitCode;
  final DateTime? completedAt;
  final bool truncated;

  /// Advisory only. True for known interactive programs such as Herdr, Codex,
  /// Claude, Pi and terminal editors. It never changes shell semantics.
  final bool interactiveHint;

  /// True after the PTY emits an alternate-screen enable sequence. Conversation
  /// Mode keeps the process alive but recommends the full terminal renderer.
  final bool fullScreenDetected;

  /// Human-readable stdin submissions sent after the command started. Raw
  /// control/accessory sequences are intentionally not recorded here.
  final List<ConversationProcessInput> processInputs;

  bool get isRunning => state == ConversationCommandState.running;

  Duration? get duration => completedAt?.difference(startedAt);

  ConversationCommand copyWith({
    ConversationCommandState? state,
    String? output,
    int? exitCode,
    bool clearExitCode = false,
    DateTime? completedAt,
    bool? truncated,
    bool? interactiveHint,
    bool? fullScreenDetected,
    List<ConversationProcessInput>? processInputs,
  }) => ConversationCommand(
    id: id,
    command: command,
    startedAt: startedAt,
    state: state ?? this.state,
    output: output ?? this.output,
    exitCode: clearExitCode ? null : exitCode ?? this.exitCode,
    completedAt: completedAt ?? this.completedAt,
    truncated: truncated ?? this.truncated,
    interactiveHint: interactiveHint ?? this.interactiveHint,
    fullScreenDetected: fullScreenDetected ?? this.fullScreenDetected,
    processInputs: processInputs ?? this.processInputs,
  );
}
